import XCTest
import TwoUpCore
@testable import TwoUp

@MainActor
final class GameViewModelTests: XCTestCase {

    private func players() -> [PlayerState] {
        [PlayerState(id: "local", name: "You", balance: 1_000, isLocal: true),
         PlayerState(id: "bot-1", name: "Bazza", balance: 1_000, isLocal: false)]
    }

    private func result(_ r: Resolution, spinner: Int = 0, next: Int = 0, first: Coin = .heads, second: Coin = .heads) -> TossResult {
        TossResult(toss: Toss(first: first, second: second), resolution: r, spinnerIndex: spinner, nextSpinnerIndex: next)
    }

    func testBannerForSpinnerWin() {
        let b = GameViewModel.banner(for: result(.spinnerWins), net: 100, players: players())
        XCTAssertEqual(b.title, "Heads, heads")
        XCTAssertEqual(b.tone, .win)
        XCTAssertTrue(b.detail.contains("+100p"))
    }

    func testBannerForLossNamesNextSpinner() {
        let b = GameViewModel.banner(for: result(.spinnerLoses(.twoTails), next: 1, first: .tails, second: .tails), net: -50, players: players())
        XCTAssertEqual(b.tone, .lose)
        XCTAssertTrue(b.detail.contains("Bazza takes the spin"))
    }

    func testBannerForFiveOddsAndReToss() {
        let five = GameViewModel.banner(for: result(.spinnerLoses(.fiveOdds), next: 1, first: .heads, second: .tails), net: 0, players: players())
        XCTAssertEqual(five.title, "Five odds")
        let odds = GameViewModel.banner(for: result(.reToss(oddsInARow: 2), first: .heads, second: .tails), net: 0, players: players())
        XCTAssertEqual(odds.tone, .neutral)
        XCTAssertTrue(odds.detail.contains("2 of 5"))
    }

    func testMoneyFormatting() {
        XCTAssertEqual(Money.short(1_000), "1,000p")
        XCTAssertEqual(Money.signed(-20), "−20p")
        XCTAssertEqual(Money.spoken(1), "1 penny")
    }

    func testEveryErrorHasAMessage() {
        let all: [GameSessionError] = [.notYourTurn, .bettingClosed, .invalidStake, .insufficientBalance, .notConnected]
        XCTAssertTrue(all.allSatisfy { !GameViewModel.message(for: $0).isEmpty })
    }
}
