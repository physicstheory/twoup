import Foundation

/// Type-erased generator so bot behaviour can be seeded in tests.
public struct AnyRandomNumberGenerator: RandomNumberGenerator {
    private var step: () -> UInt64

    public init<G: RandomNumberGenerator>(_ generator: G) {
        var g = generator
        step = { g.next() }
    }

    public mutating func next() -> UInt64 { step() }
}

public enum Nicknames {
    public static let bots = ["Bazza", "Shazza", "Davo", "Robbo", "Tazzy", "Macca", "Kezza", "Jacko",
                              "Gazza", "Mick", "Trace", "Dazza", "Lozza", "Stevo"]
}

public struct SessionTiming: Sendable {
    public var tossDuration: TimeInterval
    public var resultPause: TimeInterval
    public var botBettingWindow: TimeInterval

    public init(tossDuration: TimeInterval, resultPause: TimeInterval, botBettingWindow: TimeInterval) {
        self.tossDuration = tossDuration
        self.resultPause = resultPause
        self.botBettingWindow = botBettingWindow
    }

    public static let instant = SessionTiming(tossDuration: 0, resultPause: 0, botBettingWindow: 0)
    public static let standard = SessionTiming(tossDuration: 2.6, resultPause: 2.2, botBettingWindow: 5)
}

public struct SessionConfiguration {
    public var botCount = 5
    public var startingBalance = GameState.startingBalance
    /// Overrides the local player's opening balance (for a saved game).
    public var localStartingBalance: Int?
    public var localName = "You"
    public var timing = SessionTiming.standard
    public var fadeChance = 0.8
    public var sideBetChance = 0.25
    /// When a simulated player has the spin, toss for them after the betting window.
    public var autoplayBots = true

    public init() {}
}

/// Single-device session: the local player plus simulated players. It owns the engine, so it is the
/// authority for tosses and balances, which is the role a server would take in a networked session.
@MainActor
public final class LocalSimulatedSession<RNG: RandomNumberGenerator>: GameSession {

    public typealias Timing = SessionTiming
    public typealias Configuration = SessionConfiguration

    public static var localPlayerID: String { "local" }

    public private(set) var state: GameState
    public let events: AsyncStream<GameEvent>

    private let continuation: AsyncStream<GameEvent>.Continuation
    private var engine: TwoUpEngine<RNG>
    private var botRNG: AnyRandomNumberGenerator
    private let config: Configuration
    private var botTask: Task<Void, Never>?

    public init(configuration: Configuration = Configuration(), rng: RNG,
                botRNG: AnyRandomNumberGenerator = AnyRandomNumberGenerator(SystemRandomNumberGenerator())) {
        precondition((1...13).contains(configuration.botCount))
        var botRNG = botRNG
        let names = Nicknames.bots.shuffled(using: &botRNG)

        var players = [PlayerState(id: Self.localPlayerID, name: configuration.localName,
                                   balance: configuration.localStartingBalance ?? configuration.startingBalance,
                                   isLocal: true)]
        for i in 0..<configuration.botCount {
            players.append(PlayerState(id: "bot-\(i + 1)", name: names[i],
                                       balance: configuration.startingBalance, isLocal: false))
        }

        let (stream, continuation) = AsyncStream<GameEvent>.makeStream()
        self.events = stream
        self.continuation = continuation
        self.config = configuration
        self.botRNG = botRNG
        self.engine = TwoUpEngine(playerCount: players.count, spinnerIndex: 0, rng: rng)
        self.state = GameState(players: players, spinnerIndex: 0, phase: .betting,
                               bets: RoundBets(spinnerID: players[0].id, spinnerStake: 0))
        startBettingPhase()
    }

    // MARK: - GameSession

    public func setSpinnerStake(_ amount: Int) async throws {
        try requireBetting()
        guard state.isLocalPlayerSpinner else { throw GameSessionError.notYourTurn }
        guard amount > 0 else { throw GameSessionError.invalidStake }
        let me = state.spinner
        let sideBets = state.bets.sideBets.filter { $0.playerID == me.id }.reduce(0) { $0 + $1.stake }
        guard amount + sideBets <= me.balance else { throw GameSessionError.insufficientBalance }
        state.bets.spinnerStake = amount
        botsFade()
        publish()
    }

    public func fade(_ amount: Int) async throws {
        try requireBetting()
        guard !state.isLocalPlayerSpinner else { throw GameSessionError.notYourTurn }
        guard amount > 0, uncovered > 0 else { throw GameSessionError.invalidStake }
        let me = localPlayer
        let capped = min(amount, uncovered)
        guard capped <= me.balance - committed(me.id) else { throw GameSessionError.insufficientBalance }
        state.bets.fades.append(Fade(playerID: me.id, stake: capped))
        publish()
    }

    /// Sets this player's side bet of that kind. A stake of 0 removes it.
    public func placeSideBet(_ kind: SideBetKind, stake: Int) async throws {
        try requireBetting()
        guard stake >= 0 else { throw GameSessionError.invalidStake }
        let me = localPlayer
        let others = committed(me.id) - existingSideStake(me.id, kind)
        guard stake + others <= me.balance else { throw GameSessionError.insufficientBalance }
        setSideBet(playerID: me.id, kind: kind, stake: stake)
        publish()
    }

    public func spin() async throws {
        try requireBetting()
        guard state.isLocalPlayerSpinner else { throw GameSessionError.notYourTurn }
        guard state.bets.spinnerStake > 0 else { throw GameSessionError.invalidStake }
        await performToss()
    }

    public func resetBalance() async throws {
        guard state.phase != .tossing else { throw GameSessionError.bettingClosed }
        let id = Self.localPlayerID
        if state.bets.spinnerID == id {
            state.bets.spinnerStake = 0
            state.bets.fades = []
        }
        state.bets.fades.removeAll { $0.playerID == id }
        state.bets.sideBets.removeAll { $0.playerID == id }
        updateBalance(id) { $0 = config.startingBalance }
        publish()
    }

    public func leave() async {
        botTask?.cancel()
        botTask = nil
        continuation.finish()
    }

    // MARK: - Round flow

    private func performToss() async {
        state.phase = .tossing
        publish()

        let balances = state.players.map(\.balance)
        let result = engine.toss(eligible: { balances[$0] > 0 })
        continuation.yield(.tossed(result))
        await pause(config.timing.tossDuration)

        let settlements = TwoUpEngine<RNG>.settle(state.bets, result: result)
        for s in settlements { updateBalance(s.playerID) { $0 += s.net } }
        state.spinnerIndex = engine.spinnerIndex
        state.oddsStreak = engine.oddsStreak
        state.history = engine.history
        state.phase = .resolved
        continuation.yield(.settled(settlements))
        publish()

        await pause(config.timing.resultPause)
        prepareNextRound(after: result)
    }

    private func prepareNextRound(after result: TossResult) {
        switch result.resolution {
        case .reToss:
            state.bets.sideBets = []                     // the main bet stays on the table
        case .spinnerWins, .spinnerLoses:
            state.bets = RoundBets(spinnerID: state.spinner.id, spinnerStake: 0)
        }
        state.bets.spinnerID = state.spinner.id
        state.phase = .betting
        startBettingPhase()
    }

    private func startBettingPhase() {
        for i in state.players.indices where !state.players[i].isLocal && state.players[i].balance < 10 {
            state.players[i].balance = config.startingBalance
        }
        if !state.spinner.isLocal, state.bets.spinnerStake == 0 {
            let want = [20, 50, 50, 100, 100, 200].randomElement(using: &botRNG) ?? 50
            state.bets.spinnerStake = min(want, state.spinner.balance)
            botsFade()
        }
        botsPlaceSideBets()
        publish()
        startBotLoopIfNeeded()
    }

    private func startBotLoopIfNeeded() {
        guard config.autoplayBots, !state.spinner.isLocal, botTask == nil else { return }
        botTask = Task { [weak self] in
            await self?.runBotTurns()
            self?.botTask = nil
        }
    }

    private func runBotTurns() async {
        while !Task.isCancelled, !state.spinner.isLocal {
            await pause(config.timing.botBettingWindow)
            if Task.isCancelled { return }
            await performToss()
        }
    }

    // MARK: - Simulated players

    private func botsFade() {
        guard config.fadeChance > 0 else { return }
        for i in state.players.indices where i != state.spinnerIndex && !state.players[i].isLocal {
            let remaining = uncovered
            guard remaining > 0 else { break }
            guard Double.random(in: 0..<1, using: &botRNG) < config.fadeChance else { continue }
            let player = state.players[i]
            let free = player.balance - committed(player.id)
            let share = max(10, remaining / Int.random(in: 1...3, using: &botRNG))
            let amount = min(remaining, free, share)
            if amount > 0 { state.bets.fades.append(Fade(playerID: player.id, stake: amount)) }
        }
    }

    private func botsPlaceSideBets() {
        guard config.sideBetChance > 0 else { return }
        for player in state.players where !player.isLocal {
            guard Double.random(in: 0..<1, using: &botRNG) < config.sideBetChance else { continue }
            let kind = SideBetKind.allCases.randomElement(using: &botRNG) ?? .heads
            let stake = [5, 10, 20, 25].randomElement(using: &botRNG) ?? 10
            if stake <= player.balance - committed(player.id) {
                setSideBet(playerID: player.id, kind: kind, stake: stake)
            }
        }
    }

    // MARK: - Helpers

    private var localPlayer: PlayerState { state.players.first(where: \.isLocal)! }

    /// Part of the Spinner's stake that no one has covered yet.
    private var uncovered: Int {
        let faded = state.bets.fades.filter { $0.playerID != state.bets.spinnerID }.reduce(0) { $0 + $1.stake }
        return max(state.bets.spinnerStake - faded, 0)
    }

    private func committed(_ id: String) -> Int {
        let b = state.bets
        var total = b.fades.filter { $0.playerID == id }.reduce(0) { $0 + $1.stake }
        total += b.sideBets.filter { $0.playerID == id }.reduce(0) { $0 + $1.stake }
        if id == b.spinnerID { total += b.spinnerStake }
        return total
    }

    private func existingSideStake(_ id: String, _ kind: SideBetKind) -> Int {
        state.bets.sideBets.first { $0.playerID == id && $0.kind == kind }?.stake ?? 0
    }

    private func setSideBet(playerID: String, kind: SideBetKind, stake: Int) {
        state.bets.sideBets.removeAll { $0.playerID == playerID && $0.kind == kind }
        if stake > 0 { state.bets.sideBets.append(SideBet(playerID: playerID, kind: kind, stake: stake)) }
    }

    private func updateBalance(_ id: String, _ change: (inout Int) -> Void) {
        guard let i = state.players.firstIndex(where: { $0.id == id }) else { return }
        change(&state.players[i].balance)
    }

    private func requireBetting() throws {
        guard state.phase == .betting else { throw GameSessionError.bettingClosed }
    }

    private func publish() {
        continuation.yield(.stateChanged(state))
    }

    private func pause(_ seconds: TimeInterval) async {
        guard seconds > 0 else { return }
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
    }
}

extension LocalSimulatedSession where RNG == SystemRandomNumberGenerator {
    public convenience init(configuration: Configuration = Configuration()) {
        self.init(configuration: configuration, rng: SystemRandomNumberGenerator())
    }
}
