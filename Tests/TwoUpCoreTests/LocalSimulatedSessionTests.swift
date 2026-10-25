import XCTest
@testable import TwoUpCore

@MainActor
final class LocalSimulatedSessionTests: XCTestCase {

    private func session(_ coins: [Coin], bots: Int = 4, localBalance: Int? = nil) -> LocalSimulatedSession<ScriptedRNG> {
        var config = LocalSimulatedSession<ScriptedRNG>.Configuration()
        config.botCount = bots
        config.timing = .instant
        config.fadeChance = 1
        config.sideBetChance = 0
        config.autoplayBots = false
        config.localStartingBalance = localBalance
        return LocalSimulatedSession(configuration: config, rng: ScriptedRNG(coins))
    }

    private func total(_ s: GameState) -> Int { s.players.reduce(0) { $0 + $1.balance } }
    private var localID: String { LocalSimulatedSession<ScriptedRNG>.localPlayerID }

    func testStartsWithLocalSpinnerAndStartingBalances() {
        let s = session([H, H], bots: 6)
        XCTAssertEqual(s.state.players.count, 7)
        XCTAssertTrue(s.state.isLocalPlayerSpinner)
        XCTAssertTrue(s.state.players.allSatisfy { $0.balance == 1_000 })
        XCTAssertEqual(Set(s.state.players.map(\.name)).count, 7)
    }

    func testSpinnerWinCollectsFromTheRingAndKeepsSpinning() async throws {
        let s = session([H, H])
        let before = total(s.state)
        try await s.setSpinnerStake(100)
        let atRisk = s.state.bets.spinnerAtRisk
        XCTAssertGreaterThan(atRisk, 0)

        try await s.spin()
        XCTAssertEqual(s.state.local?.balance, 1_000 + atRisk)
        XCTAssertEqual(total(s.state), before)
        XCTAssertTrue(s.state.isLocalPlayerSpinner)
        XCTAssertEqual(s.state.bets.spinnerStake, 0)
        XCTAssertEqual(s.state.phase, .betting)
        XCTAssertEqual(s.state.history.count, 1)
    }

    func testSpinnerLossPaysTheRingAndPassesTheSpin() async throws {
        let s = session([T, T])
        try await s.setSpinnerStake(100)
        let atRisk = s.state.bets.spinnerAtRisk
        try await s.spin()
        XCTAssertEqual(s.state.local?.balance, 1_000 - atRisk)
        XCTAssertEqual(s.state.spinnerIndex, 1)
        XCTAssertFalse(s.state.isLocalPlayerSpinner)
        XCTAssertEqual(s.state.bets.spinnerID, s.state.spinner.id)
    }

    func testOddsKeepsTheMainBetOnTheTable() async throws {
        let s = session([H, T])
        try await s.setSpinnerStake(100)
        let fades = s.state.bets.fades
        try await s.spin()
        XCTAssertEqual(s.state.bets.spinnerStake, 100)
        XCTAssertEqual(s.state.bets.fades, fades)
        XCTAssertEqual(s.state.oddsStreak, 1)
        XCTAssertEqual(s.state.local?.balance, 1_000)
    }

    func testSideBetsSettleAndCanBeRemoved() async throws {
        let s = session([H, T])
        try await s.setSpinnerStake(100)
        try await s.placeSideBet(.odds, stake: 50)
        try await s.placeSideBet(.heads, stake: 30)
        try await s.placeSideBet(.heads, stake: 0)
        XCTAssertEqual(s.state.bets.sideBets.count, 1)

        try await s.spin()
        XCTAssertEqual(s.state.local?.balance, 1_000 + 100)   // odds pays 2:1 on 50
        XCTAssertTrue(s.state.bets.sideBets.isEmpty)
    }

    func testRulesAreEnforced() async throws {
        let s = session([T, T])
        await assertThrows(.invalidStake) { try await s.spin() }
        await assertThrows(.invalidStake) { try await s.setSpinnerStake(0) }
        await assertThrows(.insufficientBalance) { try await s.setSpinnerStake(5_000) }
        await assertThrows(.notYourTurn) { try await s.fade(10) }

        try await s.setSpinnerStake(100)
        try await s.spin()                                   // lose, spin passes to a bot
        await assertThrows(.notYourTurn) { try await s.setSpinnerStake(10) }
        await assertThrows(.notYourTurn) { try await s.spin() }
    }

    func testLocalPlayerCanFadeASimulatedSpinner() async throws {
        var config = LocalSimulatedSession<ScriptedRNG>.Configuration()
        config.botCount = 2
        config.timing = .instant
        config.fadeChance = 0
        config.sideBetChance = 0
        config.autoplayBots = false
        let s = LocalSimulatedSession(configuration: config, rng: ScriptedRNG([T, T, H, H]))
        try await s.setSpinnerStake(100)
        try await s.spin()                                   // local loses; bot 1 is now the spinner
        XCTAssertGreaterThan(s.state.bets.spinnerStake, 0)

        let stake = s.state.bets.spinnerStake
        try await s.fade(1_000)                              // capped to what is uncovered
        XCTAssertEqual(s.state.bets.fades.last?.stake, stake)
        await assertThrows(.invalidStake) { try await s.fade(10) }   // fully covered
    }

    func testResetBalanceIsFree() async throws {
        let s = session([H, H], localBalance: 0)
        XCTAssertEqual(s.state.local?.balance, 0)
        try await s.resetBalance()
        XCTAssertEqual(s.state.local?.balance, 1_000)
    }

    func testEventsArriveInOrder() async throws {
        let s = session([H, H])
        try await s.setSpinnerStake(50)
        try await s.spin()
        var sawTossed = false
        var iterator = s.events.makeAsyncIterator()
        while let event = await iterator.next() {
            if case .tossed = event { sawTossed = true }
            if case .settled = event { break }
        }
        XCTAssertTrue(sawTossed)
    }

    private func assertThrows(_ expected: GameSessionError, file: StaticString = #filePath, line: UInt = #line,
                              _ body: () async throws -> Void) async {
        do {
            try await body()
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? GameSessionError, expected, file: file, line: line)
        }
    }
}

private let H = Coin.heads
private let T = Coin.tails
