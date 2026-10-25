import Foundation

public struct Countdown: Equatable, Sendable {
    public let days: Int
    public let hours: Int
    public let minutes: Int
    public let seconds: Int

    public init(days: Int, hours: Int, minutes: Int, seconds: Int) {
        self.days = days
        self.hours = hours
        self.minutes = minutes
        self.seconds = seconds
    }

    public var totalSeconds: Int { ((days * 24 + hours) * 60 + minutes) * 60 + seconds }
}

public enum CommemorationDayState: Equatable, Sendable {
    case countdown(Countdown)
    case commemorationDay
}

/// Single source of truth for "what day is it relative to 25 April". Everything is evaluated in the
/// calendar's time zone (the device's, by default). A debug date can replace "now"; it keeps ticking
/// forward from the moment it was set, so a countdown still moves.
public struct CommemorationDayClock {
    public static let month = 4
    public static let day = 25

    public var calendar: Calendar
    private let now: () -> Date
    private var debugDate: Date?
    private var debugSetAt: Date?

    public init(calendar: Calendar = .current, now: @escaping () -> Date = Date.init) {
        self.calendar = calendar
        self.now = now
    }

    public var isDebugDateActive: Bool { debugDate != nil }

    /// "Today", honouring any debug override.
    public var currentDate: Date {
        guard let debugDate, let debugSetAt else { return now() }
        return debugDate.addingTimeInterval(now().timeIntervalSince(debugSetAt))
    }

    /// Pass `nil` to go back to the real date.
    public mutating func setDebugDate(_ date: Date?) {
        debugDate = date
        debugSetAt = date == nil ? nil : now()
    }

    public func isCommemorationDay(on date: Date) -> Bool {
        let c = calendar.dateComponents([.month, .day], from: date)
        return c.month == Self.month && c.day == Self.day
    }

    /// Midnight at the start of 25 April in the given year.
    public func commemorationDay(inYear year: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: Self.month, day: Self.day))!
    }

    /// The first 25 April midnight strictly after `date`. On 25 April itself that is next year's.
    public func nextCommemorationDay(after date: Date) -> Date {
        let year = calendar.component(.year, from: date)
        let thisYear = commemorationDay(inYear: year)
        return thisYear > date ? thisYear : commemorationDay(inYear: year + 1)
    }

    public func countdown(from date: Date) -> Countdown {
        let target = nextCommemorationDay(after: date)
        let c = calendar.dateComponents([.day, .hour, .minute, .second], from: date, to: target)
        return Countdown(days: c.day ?? 0, hours: c.hour ?? 0, minutes: c.minute ?? 0, seconds: c.second ?? 0)
    }

    public func state(at date: Date? = nil) -> CommemorationDayState {
        let date = date ?? currentDate
        return isCommemorationDay(on: date) ? .commemorationDay : .countdown(countdown(from: date))
    }
}
