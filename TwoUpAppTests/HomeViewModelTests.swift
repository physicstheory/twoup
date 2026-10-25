import XCTest
import TwoUpCore
@testable import TwoUp

final class HomeViewModelTests: XCTestCase {
    private func clock(at components: DateComponents) -> CommemorationDayClock {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Australia/Sydney")!
        let date = cal.date(from: components)!
        return CommemorationDayClock(calendar: cal, now: { date })
    }

    func testCountdownSnapshotSpeaksDaysHoursMinutes() {
        let snap = HomeViewModel.snapshot(clock: clock(at: DateComponents(year: 2026, month: 4, day: 24, hour: 22, minute: 59, second: 0)))
        XCTAssertEqual(snap.spokenCountdown, "0 days, 1 hour, 1 minute until 25 April")
        XCTAssertTrue(snap.dateLine.contains("25"))
    }

    func testCommemorationDaySnapshot() {
        let snap = HomeViewModel.snapshot(clock: clock(at: DateComponents(year: 2026, month: 4, day: 25, hour: 9)))
        XCTAssertEqual(snap.kind, .commemorationDay)
    }
}
