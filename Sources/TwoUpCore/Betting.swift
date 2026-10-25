import Foundation

/// Winnings per unit staked, as a fixed ratio. Stakes are returned on a win in addition to winnings;
/// the engine reports net change, so a loss is always `-stake`.
public struct Payout: Sendable, Equatable {
    public let numerator: Int
    public let denominator: Int

    public init(_ numerator: Int, to denominator: Int) {
        precondition(numerator > 0 && denominator > 0)
        self.numerator = numerator
        self.denominator = denominator
    }

    /// Even money, 1:1.
    public static let even = Payout(1, to: 1)
    /// Fixed price on the odds side bet, 2:1. This is a stated price in a play-money game.
    public static let oddsSideBet = Payout(2, to: 1)

    public func winnings(on stake: Int) -> Int {
        stake * numerator / denominator
    }

    public var label: String { "\(numerator):\(denominator)" }
}

public enum SideBetKind: String, Sendable, Codable, CaseIterable {
    case heads, tails, odds

    public var payout: Payout {
        self == .odds ? .oddsSideBet : .even
    }

    public func wins(on outcome: TossOutcome) -> Bool {
        switch (self, outcome) {
        case (.heads, .heads), (.tails, .tails), (.odds, .odds): return true
        default: return false
        }
    }
}

public struct SideBet: Sendable, Equatable {
    public let playerID: String
    public let kind: SideBetKind
    public let stake: Int

    public init(playerID: String, kind: SideBetKind, stake: Int) {
        self.playerID = playerID
        self.kind = kind
        self.stake = stake
    }
}

/// A player covering ("fading") some of the Spinner's heads stake.
public struct Fade: Sendable, Equatable {
    public let playerID: String
    public let stake: Int

    public init(playerID: String, stake: Int) {
        self.playerID = playerID
        self.stake = stake
    }
}

public struct RoundBets: Sendable, Equatable {
    public var spinnerID: String
    public var spinnerStake: Int
    public var fades: [Fade]
    public var sideBets: [SideBet]

    public init(spinnerID: String, spinnerStake: Int, fades: [Fade] = [], sideBets: [SideBet] = []) {
        self.spinnerID = spinnerID
        self.spinnerStake = spinnerStake
        self.fades = fades
        self.sideBets = sideBets
    }

    /// Fades are matched in the order placed, up to the Spinner's stake. The Spinner never fades
    /// themselves, and non-positive stakes are ignored.
    public var matchedFades: [(playerID: String, amount: Int)] {
        var remaining = max(spinnerStake, 0)
        var matched: [(playerID: String, amount: Int)] = []
        for fade in fades where fade.stake > 0 && fade.playerID != spinnerID {
            guard remaining > 0 else { break }
            let amount = min(fade.stake, remaining)
            matched.append((fade.playerID, amount))
            remaining -= amount
        }
        return matched
    }

    /// The part of the Spinner's stake that is actually at risk. Any uncovered portion is returned.
    public var spinnerAtRisk: Int {
        matchedFades.reduce(0) { $0 + $1.amount }
    }
}

/// Net change to one player's balance for a toss.
public struct Settlement: Sendable, Equatable {
    public let playerID: String
    public let net: Int

    public init(playerID: String, net: Int) {
        self.playerID = playerID
        self.net = net
    }
}
