import Foundation

public enum Coin: String, Sendable, Codable, Equatable {
    case heads, tails
}

/// What a single toss of two coins shows.
public enum TossOutcome: String, Sendable, Codable, CaseIterable {
    case heads   // two heads
    case tails   // two tails
    case odds    // one of each
}

public struct Toss: Sendable, Codable, Equatable {
    public let first: Coin
    public let second: Coin

    public init(first: Coin, second: Coin) {
        self.first = first
        self.second = second
    }

    public var outcome: TossOutcome {
        if first != second { return .odds }
        return first == .heads ? .heads : .tails
    }
}

public enum LossReason: Sendable, Codable, Equatable {
    case twoTails
    case fiveOdds
}

/// What a toss means for the Spinner's main (heads) bet.
public enum Resolution: Sendable, Codable, Equatable {
    /// Two heads: Spinner wins and keeps spinning.
    case spinnerWins
    /// Two tails, or five odds in a row: Spinner loses and the spin passes on.
    case spinnerLoses(LossReason)
    /// Odds: nothing is decided, toss again. `oddsInARow` includes this toss.
    case reToss(oddsInARow: Int)
}

public struct TossResult: Sendable, Codable, Equatable {
    public let toss: Toss
    public let resolution: Resolution
    /// Index of the player who threw this toss.
    public let spinnerIndex: Int
    /// Index of the player who throws next (same as `spinnerIndex` unless the spin passed).
    public let nextSpinnerIndex: Int

    public init(toss: Toss, resolution: Resolution, spinnerIndex: Int, nextSpinnerIndex: Int) {
        self.toss = toss
        self.resolution = resolution
        self.spinnerIndex = spinnerIndex
        self.nextSpinnerIndex = nextSpinnerIndex
    }

    public var spinPassed: Bool { spinnerIndex != nextSpinnerIndex }
}

public struct HistoryEntry: Sendable, Codable, Equatable {
    public let toss: Toss
    public let spinnerIndex: Int

    public init(toss: Toss, spinnerIndex: Int) {
        self.toss = toss
        self.spinnerIndex = spinnerIndex
    }
}
