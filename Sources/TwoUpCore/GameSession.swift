import Foundation

public struct PlayerState: Identifiable, Sendable, Equatable {
    public let id: String
    public var name: String
    public var balance: Int
    public let isLocal: Bool

    public init(id: String, name: String, balance: Int, isLocal: Bool) {
        self.id = id
        self.name = name
        self.balance = balance
        self.isLocal = isLocal
    }
}

public enum GamePhase: Sendable, Equatable {
    /// Spinner is setting a stake; others are fading and placing side bets.
    case betting
    /// Coins are in the air.
    case tossing
    /// Result is on show before the next round of betting.
    case resolved
}

public struct GameState: Sendable, Equatable {
    public static let startingBalance = 1_000

    public var players: [PlayerState]
    public var spinnerIndex: Int
    public var phase: GamePhase
    public var bets: RoundBets
    public var oddsStreak: Int
    public var history: [HistoryEntry]

    public init(players: [PlayerState], spinnerIndex: Int = 0, phase: GamePhase = .betting,
                bets: RoundBets, oddsStreak: Int = 0, history: [HistoryEntry] = []) {
        self.players = players
        self.spinnerIndex = spinnerIndex
        self.phase = phase
        self.bets = bets
        self.oddsStreak = oddsStreak
        self.history = history
    }

    public var spinner: PlayerState { players[spinnerIndex] }
    public var local: PlayerState? { players.first(where: \.isLocal) }
    public var isLocalPlayerSpinner: Bool { spinner.isLocal }
}

public enum GameEvent: Sendable, Equatable {
    case stateChanged(GameState)
    case tossed(TossResult)
    case settled([Settlement])
    case playerJoined(PlayerState)
    case playerLeft(id: String)
}

public enum GameSessionError: Error, Equatable {
    case notYourTurn
    case bettingClosed
    case invalidStake
    case insufficientBalance
    case notConnected
}

/// The seam between the UI and wherever the game runs. `LocalSimulatedSession` plays against bots
/// on this device; a networked implementation can replace it without changing any view or view model.
/// A networked session must treat the server as the authority for tosses and balances.
@MainActor
public protocol GameSession: AnyObject {
    var state: GameState { get }
    var events: AsyncStream<GameEvent> { get }

    func setSpinnerStake(_ amount: Int) async throws
    func fade(_ amount: Int) async throws
    func placeSideBet(_ kind: SideBetKind, stake: Int) async throws
    func spin() async throws
    /// Free reset of the local player's play-money balance. Never purchasable.
    func resetBalance() async throws
    func leave() async
}
