import XCTest
@testable import TwoUpCore

/// Replays a fixed list of coins. Even value = heads, odd = tails (matches the engine's flip).
struct ScriptedRNG: RandomNumberGenerator {
    private let values: [UInt64]
    private var index = 0

    init(_ coins: [Coin]) {
        values = coins.map { $0 == .heads ? 0 : 1 }
    }

    mutating func next() -> UInt64 {
        precondition(index < values.count, "Script exhausted")
        defer { index += 1 }
        return values[index]
    }
}

/// SplitMix64: small, deterministic, good enough for distribution checks.
struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

private let H = Coin.heads
private let T = Coin.tails

final class TwoUpEngineTests: XCTestCase {

    private func engine(_ coins: [Coin], players: Int = 4, spinner: Int = 0) -> TwoUpEngine<ScriptedRNG> {
        TwoUpEngine(playerCount: players, spinnerIndex: spinner, rng: ScriptedRNG(coins))
    }

    // MARK: Outcomes

    func testTossOutcomeClassification() {
        XCTAssertEqual(Toss(first: H, second: H).outcome, .heads)
        XCTAssertEqual(Toss(first: T, second: T).outcome, .tails)
        XCTAssertEqual(Toss(first: H, second: T).outcome, .odds)
        XCTAssertEqual(Toss(first: T, second: H).outcome, .odds)
    }

    func testTwoHeadsSpinnerWinsAndKeepsSpinning() {
        var e = engine([H, H], spinner: 2)
        let r = e.toss()
        XCTAssertEqual(r.resolution, .spinnerWins)
        XCTAssertEqual(r.spinnerIndex, 2)
        XCTAssertEqual(r.nextSpinnerIndex, 2)
        XCTAssertFalse(r.spinPassed)
        XCTAssertEqual(e.spinnerIndex, 2)
    }

    func testTwoTailsSpinnerLosesAndSpinPasses() {
        var e = engine([T, T], spinner: 1)
        let r = e.toss()
        XCTAssertEqual(r.resolution, .spinnerLoses(.twoTails))
        XCTAssertEqual(r.nextSpinnerIndex, 2)
        XCTAssertTrue(r.spinPassed)
        XCTAssertEqual(e.spinnerIndex, 2)
    }

    func testOddsMeansReTossAndSpinStays() {
        var e = engine([H, T])
        let r = e.toss()
        XCTAssertEqual(r.resolution, .reToss(oddsInARow: 1))
        XCTAssertEqual(e.oddsStreak, 1)
        XCTAssertEqual(e.spinnerIndex, 0)
    }

    // MARK: Five odds

    func testFourOddsThenHeadsResetsStreak() {
        var e = engine([H, T, T, H, H, T, T, H, H, H])
        for expected in 1...4 {
            XCTAssertEqual(e.toss().resolution, .reToss(oddsInARow: expected))
        }
        XCTAssertEqual(e.oddsStreak, 4)
        XCTAssertEqual(e.toss().resolution, .spinnerWins)
        XCTAssertEqual(e.oddsStreak, 0)
    }

    func testFiveOddsInARowLosesAndPassesSpin() {
        var e = engine([H, T, T, H, H, T, T, H, H, T])
        for _ in 1...4 { _ = e.toss() }
        let fifth = e.toss()
        XCTAssertEqual(fifth.resolution, .spinnerLoses(.fiveOdds))
        XCTAssertEqual(fifth.spinnerIndex, 0)
        XCTAssertEqual(fifth.nextSpinnerIndex, 1)
        XCTAssertEqual(e.oddsStreak, 0)
    }

    func testOddsStreakResetsOnTails() {
        var e = engine([H, T, T, T, H, T, T, H, H, T, T, H])
        _ = e.toss()                    // odds (1)
        _ = e.toss()                    // tails: streak resets, spin passes
        XCTAssertEqual(e.oddsStreak, 0)
        for expected in 1...3 {         // new spinner starts counting from one again
            XCTAssertEqual(e.toss().resolution, .reToss(oddsInARow: expected))
        }
    }

    // MARK: Spinner rotation

    func testRotationWrapsAround() {
        var e = engine([T, T, T, T, T, T, T, T], players: 3, spinner: 0)
        XCTAssertEqual(e.toss().nextSpinnerIndex, 1)
        XCTAssertEqual(e.toss().nextSpinnerIndex, 2)
        XCTAssertEqual(e.toss().nextSpinnerIndex, 0)
        XCTAssertEqual(e.toss().nextSpinnerIndex, 1)
    }

    func testRotationSkipsIneligiblePlayers() {
        var e = engine([T, T], players: 4, spinner: 0)
        let r = e.toss(eligible: { $0 != 1 && $0 != 2 })
        XCTAssertEqual(r.nextSpinnerIndex, 3)
    }

    func testRotationStaysWhenNobodyElseIsEligible() {
        var e = engine([T, T], players: 3, spinner: 1)
        let r = e.toss(eligible: { $0 == 1 })
        XCTAssertEqual(r.nextSpinnerIndex, 1)
    }

    func testSinglePlayerRotationStaysPut() {
        var e = engine([T, T], players: 1)
        XCTAssertEqual(e.toss().nextSpinnerIndex, 0)
    }

    func testWinDoesNotRotate() {
        var e = engine([H, H, H, H], players: 3)
        _ = e.toss(); _ = e.toss()
        XCTAssertEqual(e.spinnerIndex, 0)
    }

    // MARK: History

    func testHistoryRecordsThrowerAndCapsAtTwenty() {
        var e = engine(Array(repeating: T, count: 50), players: 3)
        for _ in 0..<25 { _ = e.toss() }
        XCTAssertEqual(e.history.count, 20)
        // Tosses 6...25 remain; toss n was thrown by player (n - 1) % 3.
        XCTAssertEqual(e.history.first?.spinnerIndex, 5 % 3)
        XCTAssertEqual(e.history.last?.spinnerIndex, 24 % 3)
    }

    // MARK: Randomness

    func testCoinsAreRoughlyFair() {
        var e = TwoUpEngine(playerCount: 2, rng: SeededRNG(seed: 42))
        var counts: [TossOutcome: Int] = [:]
        let n = 20_000
        for _ in 0..<n { counts[e.toss().toss.outcome, default: 0] += 1 }
        let heads = Double(counts[.heads] ?? 0) / Double(n)
        let tails = Double(counts[.tails] ?? 0) / Double(n)
        let odds = Double(counts[.odds] ?? 0) / Double(n)
        XCTAssertEqual(heads, 0.25, accuracy: 0.02)
        XCTAssertEqual(tails, 0.25, accuracy: 0.02)
        XCTAssertEqual(odds, 0.50, accuracy: 0.02)
    }

    func testSameSeedGivesSameSequence() {
        var a = TwoUpEngine(playerCount: 3, rng: SeededRNG(seed: 7))
        var b = TwoUpEngine(playerCount: 3, rng: SeededRNG(seed: 7))
        for _ in 0..<100 { XCTAssertEqual(a.toss(), b.toss()) }
    }

    // MARK: Payouts

    private func settle(_ bets: RoundBets, _ coins: [Coin]) -> [String: Int] {
        var e = TwoUpEngine(playerCount: 4, rng: ScriptedRNG(coins))
        let result = e.toss()
        return Dictionary(uniqueKeysWithValues: TwoUpEngine<ScriptedRNG>.settle(bets, result: result).map { ($0.playerID, $0.net) })
    }

    func testPayoutRatios() {
        XCTAssertEqual(Payout.even.winnings(on: 100), 100)
        XCTAssertEqual(Payout.oddsSideBet.winnings(on: 100), 200)
        XCTAssertEqual(Payout.even.label, "1:1")
        XCTAssertEqual(Payout.oddsSideBet.label, "2:1")
        XCTAssertEqual(SideBetKind.heads.payout, .even)
        XCTAssertEqual(SideBetKind.tails.payout, .even)
        XCTAssertEqual(SideBetKind.odds.payout, .oddsSideBet)
    }

    func testSpinnerWinsCollectsFromFaders() {
        let bets = RoundBets(spinnerID: "S", spinnerStake: 100,
                             fades: [Fade(playerID: "A", stake: 60), Fade(playerID: "B", stake: 40)])
        let net = settle(bets, [H, H])
        XCTAssertEqual(net["S"], 100)
        XCTAssertEqual(net["A"], -60)
        XCTAssertEqual(net["B"], -40)
    }

    func testSpinnerLosesPaysFaders() {
        let bets = RoundBets(spinnerID: "S", spinnerStake: 100,
                             fades: [Fade(playerID: "A", stake: 60), Fade(playerID: "B", stake: 40)])
        let net = settle(bets, [T, T])
        XCTAssertEqual(net["S"], -100)
        XCTAssertEqual(net["A"], 60)
        XCTAssertEqual(net["B"], 40)
    }

    func testUncoveredStakeIsReturned() {
        let bets = RoundBets(spinnerID: "S", spinnerStake: 100, fades: [Fade(playerID: "A", stake: 30)])
        XCTAssertEqual(bets.spinnerAtRisk, 30)
        XCTAssertEqual(settle(bets, [H, H])["S"], 30)
        XCTAssertEqual(settle(bets, [T, T])["S"], -30)
    }

    func testOverfadingIsCappedInOrderPlaced() {
        let bets = RoundBets(spinnerID: "S", spinnerStake: 100,
                             fades: [Fade(playerID: "A", stake: 80), Fade(playerID: "B", stake: 80)])
        let net = settle(bets, [H, H])
        XCTAssertEqual(net["A"], -80)
        XCTAssertEqual(net["B"], -20)
        XCTAssertEqual(net["S"], 100)
    }

    func testSpinnerCannotFadeThemselves() {
        let bets = RoundBets(spinnerID: "S", spinnerStake: 100, fades: [Fade(playerID: "S", stake: 100)])
        XCTAssertEqual(bets.spinnerAtRisk, 0)
        XCTAssertTrue(settle(bets, [H, H]).isEmpty)
    }

    func testOddsLeavesMainBetUnsettled() {
        let bets = RoundBets(spinnerID: "S", spinnerStake: 100, fades: [Fade(playerID: "A", stake: 100)])
        XCTAssertTrue(settle(bets, [H, T]).isEmpty)
    }

    func testFiveOddsLosesMainBetAndWinsOddsSideBets() {
        var e = TwoUpEngine(playerCount: 4, rng: ScriptedRNG([H, T, T, H, H, T, T, H, H, T]))
        for _ in 1...4 { _ = e.toss() }
        let fifth = e.toss()
        let bets = RoundBets(spinnerID: "S", spinnerStake: 100,
                             fades: [Fade(playerID: "A", stake: 100)],
                             sideBets: [SideBet(playerID: "B", kind: .odds, stake: 50),
                                        SideBet(playerID: "C", kind: .heads, stake: 50)])
        let net = Dictionary(uniqueKeysWithValues: TwoUpEngine<ScriptedRNG>.settle(bets, result: fifth).map { ($0.playerID, $0.net) })
        XCTAssertEqual(net["S"], -100)
        XCTAssertEqual(net["A"], 100)
        XCTAssertEqual(net["B"], 100)   // 2:1
        XCTAssertEqual(net["C"], -50)
    }

    func testSideBetsSettleOnEveryToss() {
        let sides = [SideBet(playerID: "H", kind: .heads, stake: 10),
                     SideBet(playerID: "T", kind: .tails, stake: 10),
                     SideBet(playerID: "O", kind: .odds, stake: 10)]
        let bets = RoundBets(spinnerID: "S", spinnerStake: 0, sideBets: sides)

        let onHeads = settle(bets, [H, H])
        XCTAssertEqual([onHeads["H"], onHeads["T"], onHeads["O"]], [10, -10, -10])

        let onTails = settle(bets, [T, T])
        XCTAssertEqual([onTails["H"], onTails["T"], onTails["O"]], [-10, 10, -10])

        let onOdds = settle(bets, [T, H])
        XCTAssertEqual([onOdds["H"], onOdds["T"], onOdds["O"]], [-10, -10, 20])
    }

    func testSettlementsAreZeroSum() {
        let bets = RoundBets(spinnerID: "S", spinnerStake: 100,
                             fades: [Fade(playerID: "A", stake: 70), Fade(playerID: "B", stake: 30)])
        for coins in [[H, H], [T, T]] {
            let total = settle(bets, coins).values.reduce(0, +)
            XCTAssertEqual(total, 0)
        }
    }

    func testPlayerWithMainAndSideBetsIsAggregated() {
        let bets = RoundBets(spinnerID: "S", spinnerStake: 100,
                             fades: [Fade(playerID: "A", stake: 100)],
                             sideBets: [SideBet(playerID: "A", kind: .heads, stake: 25)])
        var e = TwoUpEngine(playerCount: 2, rng: ScriptedRNG([H, H]))
        let settlements = TwoUpEngine<ScriptedRNG>.settle(bets, result: e.toss())
        XCTAssertEqual(settlements.filter { $0.playerID == "A" }.count, 1)
        XCTAssertEqual(settlements.first { $0.playerID == "A" }?.net, -75)   // -100 fade, +25 side bet
    }
}
