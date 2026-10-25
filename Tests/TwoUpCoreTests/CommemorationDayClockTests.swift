import XCTest
@testable import TwoUpCore

final class CommemorationDayClockTests: XCTestCase {

    private func calendar(_ tz: String) -> Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: tz)!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0, _ s: Int = 0, in cal: Calendar) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min, second: s))!
    }

    private func clock(_ tz: String = "Australia/Sydney") -> CommemorationDayClock {
        CommemorationDayClock(calendar: calendar(tz), now: { Date(timeIntervalSince1970: 0) })
    }

    private func countdown(_ clock: CommemorationDayClock, _ d: Date) -> Countdown {
        guard case .countdown(let c) = clock.state(at: d) else {
            XCTFail("Expected a countdown"); return Countdown(days: -1, hours: 0, minutes: 0, seconds: 0)
        }
        return c
    }

    // MARK: Year boundaries

    func testCountdownAcrossNewYear() {
        let k = clock(); let cal = k.calendar
        // 1s to midnight Jan 1, then Jan 1 -> Apr 25 is 114 days in a non-leap year.
        XCTAssertEqual(countdown(k, date(2026, 12, 31, 23, 59, 59, in: cal)),
                       Countdown(days: 114, hours: 0, minutes: 0, seconds: 1))
    }

    func testNewYearsDayNonLeapAndLeap() {
        let k = clock(); let cal = k.calendar
        XCTAssertEqual(countdown(k, date(2027, 1, 1, in: cal)).days, 114)
        XCTAssertEqual(countdown(k, date(2028, 1, 1, in: cal)).days, 115)   // 2028 is a leap year
    }

    // MARK: Leap years

    func testLeapDayIsCountedWhenItLiesAhead() {
        let k = clock(); let cal = k.calendar
        XCTAssertEqual(countdown(k, date(2028, 2, 28, 12, in: cal)),
                       Countdown(days: 56, hours: 12, minutes: 0, seconds: 0))
        XCTAssertEqual(countdown(k, date(2027, 2, 28, 12, in: cal)),
                       Countdown(days: 55, hours: 12, minutes: 0, seconds: 0))
    }

    func testLeapDayIsNotCountedWhenItIsBehind() {
        let k = clock(); let cal = k.calendar
        XCTAssertEqual(countdown(k, date(2028, 3, 1, in: cal)).days, 55)
    }

    func testFullYearSpanningLeapDay() {
        let k = clock(); let cal = k.calendar
        XCTAssertEqual(countdown(k, date(2027, 4, 26, in: cal)).days, 365)   // Apr 26 2027 -> Apr 25 2028 includes Feb 29
        XCTAssertEqual(countdown(k, date(2026, 4, 26, in: cal)).days, 364)
    }

    // MARK: 25 April itself and the day after

    func testStartOfCommemorationDay() {
        let k = clock(); let cal = k.calendar
        let midnight = date(2026, 4, 25, in: cal)
        XCTAssertTrue(k.isCommemorationDay(on: midnight))
        XCTAssertEqual(k.state(at: midnight), .commemorationDay)
    }

    func testEndOfCommemorationDay() {
        let k = clock(); let cal = k.calendar
        XCTAssertEqual(k.state(at: date(2026, 4, 25, 23, 59, 59, in: cal)), .commemorationDay)
    }

    func testOneSecondBeforeCommemorationDay() {
        let k = clock(); let cal = k.calendar
        XCTAssertEqual(countdown(k, date(2026, 4, 24, 23, 59, 59, in: cal)),
                       Countdown(days: 0, hours: 0, minutes: 0, seconds: 1))
    }

    func testDayAfterCommemorationDayCountsToNextYear() {
        let k = clock(); let cal = k.calendar
        let c = countdown(k, date(2026, 4, 26, in: cal))
        XCTAssertEqual(c, Countdown(days: 364, hours: 0, minutes: 0, seconds: 0))
        XCTAssertFalse(k.isCommemorationDay(on: date(2026, 4, 26, in: cal)))
    }

    func testNextCommemorationDayIsStrictlyAfter() {
        let k = clock(); let cal = k.calendar
        XCTAssertEqual(k.nextCommemorationDay(after: date(2026, 4, 25, in: cal)), date(2027, 4, 25, in: cal))
        XCTAssertEqual(k.nextCommemorationDay(after: date(2026, 4, 24, 23, 59, 59, in: cal)), date(2026, 4, 25, in: cal))
        XCTAssertEqual(k.nextCommemorationDay(after: date(2026, 12, 31, in: cal)), date(2027, 4, 25, in: cal))
    }

    func testOtherDatesAreNotCommemorationDay() {
        let k = clock(); let cal = k.calendar
        XCTAssertFalse(k.isCommemorationDay(on: date(2026, 4, 24, in: cal)))
        XCTAssertFalse(k.isCommemorationDay(on: date(2026, 5, 25, in: cal)))
        XCTAssertFalse(k.isCommemorationDay(on: date(2026, 4, 5, in: cal)))
    }

    // MARK: Time zones

    func testSameInstantDifferentTimeZones() {
        // 2026-04-24 14:30 UTC is 00:30 on 25 April in Sydney (AEST), but 22:30 on the 24th in Perth.
        let instant = ISO8601DateFormatter().date(from: "2026-04-24T14:30:00Z")!
        XCTAssertEqual(clock("Australia/Sydney").state(at: instant), .commemorationDay)
        XCTAssertEqual(clock("Australia/Perth").state(at: instant),
                       .countdown(Countdown(days: 0, hours: 1, minutes: 30, seconds: 0)))
        XCTAssertEqual(clock("UTC").state(at: instant),
                       .countdown(Countdown(days: 0, hours: 9, minutes: 30, seconds: 0)))
    }

    func testCommemorationDayIsLocalNotUTC() {
        // 2026-04-25 15:00 UTC is already 26 April in Sydney.
        let instant = ISO8601DateFormatter().date(from: "2026-04-25T15:00:00Z")!
        XCTAssertEqual(clock("UTC").state(at: instant), .commemorationDay)
        XCTAssertNotEqual(clock("Australia/Sydney").state(at: instant), .commemorationDay)
    }

    func testCountdownAcrossDaylightSavingEnd() {
        // Sydney's daylight saving ends on 5 April 2026; the countdown still lands on midnight 25 April.
        let k = clock(); let cal = k.calendar
        let c = countdown(k, date(2026, 4, 4, in: cal))
        XCTAssertEqual(c, Countdown(days: 21, hours: 0, minutes: 0, seconds: 0))
    }

    // MARK: Debug override

    private final class Box { var date: Date; init(_ d: Date) { date = d } }

    func testDebugDateOverridesAndKeepsTicking() {
        let cal = calendar("Australia/Sydney")
        let real = Box(date(2026, 1, 1, in: cal))
        var k = CommemorationDayClock(calendar: cal, now: { real.date })
        XCTAssertFalse(k.isDebugDateActive)
        XCTAssertEqual(k.currentDate, real.date)

        k.setDebugDate(date(2026, 4, 24, 23, 59, 50, in: cal))
        XCTAssertTrue(k.isDebugDateActive)
        XCTAssertEqual(k.state(), .countdown(Countdown(days: 0, hours: 0, minutes: 0, seconds: 10)))

        real.date = real.date.addingTimeInterval(10)   // ten real seconds later
        XCTAssertEqual(k.state(), .commemorationDay)

        k.setDebugDate(nil)
        XCTAssertEqual(k.currentDate, real.date)
    }
}
