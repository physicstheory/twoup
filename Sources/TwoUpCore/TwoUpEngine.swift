import Foundation

/// Pure game logic for Two-Up. No UI, no I/O; randomness is injected so it is fully testable.
///
/// Rules: two heads, the Spinner wins and keeps spinning. Two tails, the Spinner loses and the spin
/// passes. One of each ("odds"), toss again; five odds in a row and the Spinner loses.
public struct TwoUpEngine<RNG: RandomNumberGenerator> {
    public static var maxOddsInARow: Int { 5 }
    public static var historyLimit: Int { 20 }

    public let playerCount: Int
    public private(set) var spinnerIndex: Int
    public private(set) var oddsStreak: Int = 0
    /// Most recent tosses, oldest first, capped at `historyLimit`.
    public private(set) var history: [HistoryEntry] = []

    private var rng: RNG

    public init(playerCount: Int, spinnerIndex: Int = 0, rng: RNG) {
        precondition(playerCount >= 1, "Two-Up needs at least one player")
        precondition((0..<playerCount).contains(spinnerIndex))
        self.playerCount = playerCount
        self.spinnerIndex = spinnerIndex
        self.rng = rng
    }

    /// Flips one coin: an even random value is heads.
    private mutating func flip() -> Coin {
        rng.next() & 1 == 0 ? .heads : .tails
    }

    /// Tosses both coins and applies the rules. `eligible` lets the caller skip players who
    /// cannot take the spin (for example, players with no balance).
    @discardableResult
    public mutating func toss(eligible: (Int) -> Bool = { _ in true }) -> TossResult {
        let toss = Toss(first: flip(), second: flip())
        let thrower = spinnerIndex
        let resolution: Resolution

        switch toss.outcome {
        case .heads:
            oddsStreak = 0
            resolution = .spinnerWins
        case .tails:
            oddsStreak = 0
            resolution = .spinnerLoses(.twoTails)
            rotateSpinner(eligible: eligible)
        case .odds:
            oddsStreak += 1
            if oddsStreak >= Self.maxOddsInARow {
                oddsStreak = 0
                resolution = .spinnerLoses(.fiveOdds)
                rotateSpinner(eligible: eligible)
            } else {
                resolution = .reToss(oddsInARow: oddsStreak)
            }
        }

        history.append(HistoryEntry(toss: toss, spinnerIndex: thrower))
        if history.count > Self.historyLimit {
            history.removeFirst(history.count - Self.historyLimit)
        }

        return TossResult(toss: toss, resolution: resolution, spinnerIndex: thrower, nextSpinnerIndex: spinnerIndex)
    }

    /// Passes the spin to the next eligible player. If nobody else is eligible it stays put.
    public mutating func rotateSpinner(eligible: (Int) -> Bool = { _ in true }) {
        for step in 1...playerCount {
            let candidate = (spinnerIndex + step) % playerCount
            if eligible(candidate) {
                spinnerIndex = candidate
                return
            }
        }
    }

    // MARK: - Settlement

    /// Works out each player's net balance change for a toss. Side bets settle on every toss.
    /// The main bet only settles when the toss resolves it (not on a re-toss).
    public static func settle(_ bets: RoundBets, result: TossResult) -> [Settlement] {
        var order: [String] = []
        var net: [String: Int] = [:]

        func add(_ id: String, _ amount: Int) {
            if net[id] == nil { order.append(id) }
            net[id, default: 0] += amount
        }

        for bet in bets.sideBets where bet.stake > 0 {
            if bet.kind.wins(on: result.toss.outcome) {
                add(bet.playerID, bet.kind.payout.winnings(on: bet.stake))
            } else {
                add(bet.playerID, -bet.stake)
            }
        }

        let spinnerWon: Bool
        switch result.resolution {
        case .reToss: return order.map { Settlement(playerID: $0, net: net[$0] ?? 0) }
        case .spinnerWins: spinnerWon = true
        case .spinnerLoses: spinnerWon = false
        }

        for (playerID, amount) in bets.matchedFades {
            add(playerID, spinnerWon ? -amount : amount)
            add(bets.spinnerID, spinnerWon ? amount : -amount)
        }

        return order.map { Settlement(playerID: $0, net: net[$0] ?? 0) }
    }
}

extension TwoUpEngine where RNG == SystemRandomNumberGenerator {
    public init(playerCount: Int, spinnerIndex: Int = 0) {
        self.init(playerCount: playerCount, spinnerIndex: spinnerIndex, rng: SystemRandomNumberGenerator())
    }
}
