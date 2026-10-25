import SwiftUI
import UIKit
import TwoUpCore

/// What the 3D scene must do. Kept free of SceneKit so the view model can be tested with a stub.
@MainActor
protocol TossAnimating: AnyObject {
    func setViewpoint(spinnerIsLocal: Bool, animated: Bool)
    func animate(_ toss: Toss, spinnerIsLocal: Bool, duration: TimeInterval, reduceMotion: Bool, onLand: @escaping () -> Void)
    func celebrate(positive: Bool, reduceMotion: Bool)
}

struct ResultBanner: Equatable {
    enum Tone { case win, lose, neutral }
    let title: String
    let detail: String
    let tone: Tone
}

@MainActor
final class GameViewModel: ObservableObject {
    @Published private(set) var state: GameState
    @Published private(set) var banner: ResultBanner?
    @Published private(set) var lastToss: Toss?
    @Published private(set) var isCoinInFlight = false
    @Published var stakeDraft = 50 { didSet { stakeDraft = max(10, stakeDraft) } }
    @Published var sideStake = 25
    @Published var showResetOffer = false
    @Published var errorMessage: String?

    let mode: GameMode
    weak var animator: TossAnimating?

    private let session: any GameSession
    private let settings: SettingsStore
    private let haptics: HapticsService
    private let sound: SoundService
    private var eventTask: Task<Void, Never>?
    private var lastResult: TossResult?
    private var resetOfferDismissed = false

    static let stakeChoices = [10, 50, 100, 250]
    static let sideStakeChoices = [10, 25, 50]

    init(mode: GameMode, session: any GameSession, settings: SettingsStore, haptics: HapticsService, sound: SoundService) {
        self.mode = mode
        self.session = session
        self.settings = settings
        self.haptics = haptics
        self.sound = sound
        self.state = session.state
    }

    /// Builds the on-device simulated session. A networked session would be swapped in here.
    static func local(mode: GameMode, env: AppEnvironment) -> GameViewModel {
        var config = SessionConfiguration()
        config.botCount = mode.botCount
        config.localStartingBalance = env.settings.localBalance
        let session = LocalSimulatedSession<SystemRandomNumberGenerator>(configuration: config)
        return GameViewModel(mode: mode, session: session, settings: env.settings, haptics: env.haptics, sound: env.sound)
    }

    // MARK: Lifecycle

    func start() {
        guard eventTask == nil else { return }
        let session = self.session
        eventTask = Task { [weak self] in
            for await event in session.events {
                guard let self else { return }
                self.handle(event)
            }
        }
        handle(.stateChanged(session.state))
        animator?.setViewpoint(spinnerIsLocal: state.isLocalPlayerSpinner, animated: false)
    }

    func stop() {
        eventTask?.cancel()
        eventTask = nil
        Task { await session.leave() }
    }

    // MARK: Derived

    var local: PlayerState { state.local ?? state.players[0] }
    var isSpinner: Bool { state.isLocalPlayerSpinner }
    var isBetting: Bool { state.phase == .betting }

    /// Part of the Spinner's stake nobody has covered.
    var uncovered: Int {
        let faded = state.bets.fades.filter { $0.playerID != state.bets.spinnerID }.reduce(0) { $0 + $1.stake }
        return max(state.bets.spinnerStake - faded, 0)
    }

    var localFade: Int { state.bets.fades.filter { $0.playerID == local.id }.reduce(0) { $0 + $1.stake } }

    func sideBetStake(_ kind: SideBetKind) -> Int {
        state.bets.sideBets.first { $0.playerID == local.id && $0.kind == kind }?.stake ?? 0
    }

    var available: Int {
        let b = state.bets
        let used = b.fades.filter { $0.playerID == local.id }.reduce(0) { $0 + $1.stake }
            + b.sideBets.filter { $0.playerID == local.id }.reduce(0) { $0 + $1.stake }
            + (isSpinner ? b.spinnerStake : 0)
        return max(local.balance - used, 0)
    }

    var coinsDescription: String {
        guard let toss = lastToss else { return "Two coins on the kip" }
        if isCoinInFlight { return "Two coins in the air" }
        switch toss.outcome {
        case .heads: return "Two coins landed: both heads"
        case .tails: return "Two coins landed: both tails"
        case .odds: return "Two coins landed: one head, one tail. Odds"
        }
    }

    // MARK: Actions

    func setStake(_ amount: Int) {
        stakeDraft = amount
        perform { try await self.session.setSpinnerStake(self.stakeDraft) }
    }

    func toss() {
        perform { try await self.session.spin() }
    }

    func fade(_ amount: Int) {
        perform { try await self.session.fade(amount) }
    }

    func toggleSideBet(_ kind: SideBetKind) {
        let stake = sideBetStake(kind) > 0 ? 0 : sideStake
        haptics.tap()
        perform { try await self.session.placeSideBet(kind, stake: stake) }
    }

    func dismissResetOffer() {
        resetOfferDismissed = true
        showResetOffer = false
    }

    func resetBalance() {
        showResetOffer = false
        perform { try await self.session.resetBalance() }
    }

    private func perform(_ work: @escaping () async throws -> Void) {
        Task { [weak self] in
            do { try await work() }
            catch let error as GameSessionError { self?.errorMessage = Self.message(for: error) }
            catch { self?.errorMessage = error.localizedDescription }
        }
    }

    static func message(for error: GameSessionError) -> String {
        switch error {
        case .notYourTurn: return "It's not your spin."
        case .bettingClosed: return "Hold on, the coins are in the air."
        case .invalidStake: return "Pick an amount first."
        case .insufficientBalance: return "You don't have enough pennies for that."
        case .notConnected: return "Not connected."
        }
    }

    // MARK: Events

    func handle(_ event: GameEvent) {
        switch event {
        case .stateChanged(let s):
            let spinnerChanged = s.spinner.id != state.spinner.id
            state = s
            settings.localBalance = local.balance
            if spinnerChanged { animator?.setViewpoint(spinnerIsLocal: s.isLocalPlayerSpinner, animated: true) }
            if local.balance > 0 { resetOfferDismissed = false }
            if local.balance == 0 && s.phase == .betting && !resetOfferDismissed { showResetOffer = true }

        case .tossed(let result):
            lastResult = result
            lastToss = result.toss
            isCoinInFlight = true
            banner = nil
            haptics.tossStart()
            sound.play(.toss)
            animator?.animate(result.toss, spinnerIsLocal: state.isLocalPlayerSpinner,
                              duration: 1.6, reduceMotion: UIAccessibility.isReduceMotionEnabled) { [weak self] in
                self?.haptics.coinLand()
                self?.sound.play(.land)
            }

        case .settled(let settlements):
            isCoinInFlight = false
            guard let result = lastResult else { return }
            let net = settlements.first { $0.playerID == local.id }?.net ?? 0
            let banner = Self.banner(for: result, net: net, players: state.players)
            self.banner = banner
            switch banner.tone {
            case .win: haptics.win(); sound.play(.win)
            case .lose: haptics.lose(); sound.play(.lose)
            case .neutral: break
            }
            animator?.celebrate(positive: result.resolution == .spinnerWins,
                                reduceMotion: UIAccessibility.isReduceMotionEnabled)
            UIAccessibility.post(notification: .announcement, argument: "\(banner.title). \(banner.detail)")

        case .playerJoined, .playerLeft:
            break
        }
    }

    static func banner(for result: TossResult, net: Int, players: [PlayerState]) -> ResultBanner {
        let spinner = players[result.spinnerIndex]
        let next = players[result.nextSpinnerIndex]
        let you = spinner.isLocal
        let netLine = net == 0 ? "" : " \(Money.signed(net))"
        let takes = next.isLocal ? "You take the spin." : "\(next.name) takes the spin."
        let out = you ? "You're out." : "\(spinner.name) is out."

        switch result.resolution {
        case .spinnerWins:
            let who = you ? "You win and keep spinning." : "\(spinner.name) wins and keeps spinning."
            return ResultBanner(title: "Heads, heads", detail: who + netLine, tone: net < 0 ? .lose : .win)
        case .spinnerLoses(.twoTails):
            return ResultBanner(title: "Tails, tails", detail: "\(out) \(takes)\(netLine)", tone: net > 0 ? .win : .lose)
        case .spinnerLoses(.fiveOdds):
            return ResultBanner(title: "Five odds", detail: "\(out) \(takes)\(netLine)", tone: net > 0 ? .win : .lose)
        case .reToss(let n):
            return ResultBanner(title: "Odds", detail: "Toss again. That's \(n) of 5 in a row.\(netLine)",
                                tone: net > 0 ? .win : (net < 0 ? .lose : .neutral))
        }
    }
}
