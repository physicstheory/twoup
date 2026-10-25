import Foundation
import TwoUpCore

enum GameMode: String, Identifiable {
    case practice, commemorationDay
    var id: String { rawValue }

    var botCount: Int { self == .practice ? 5 : 7 }
    var title: String { self == .practice ? "Practice" : "25 April" }
}

/// Turns the clock's state into what the home screen shows.
struct HomeSnapshot: Equatable {
    enum Kind: Equatable {
        case countdown(Countdown)
        case commemorationDay
    }

    let kind: Kind
    let dateLine: String

    var spokenCountdown: String {
        switch kind {
        case .commemorationDay:
            return "It is 25 April. Lest we forget."
        case .countdown(let c):
            return "\(Self.plural(c.days, "day")), \(Self.plural(c.hours, "hour")), "
                + "\(Self.plural(c.minutes, "minute")) until 25 April"
        }
    }

    private static func plural(_ n: Int, _ unit: String) -> String { "\(n) \(unit)\(n == 1 ? "" : "s")" }
}

enum HomeViewModel {
    static func snapshot(clock: CommemorationDayClock) -> HomeSnapshot {
        let now = clock.currentDate
        let target: Date
        let kind: HomeSnapshot.Kind
        switch clock.state(at: now) {
        case .commemorationDay:
            target = clock.commemorationDay(inYear: clock.calendar.component(.year, from: now))
            kind = .commemorationDay
        case .countdown(let c):
            target = clock.nextCommemorationDay(after: now)
            kind = .countdown(c)
        }
        let formatter = DateFormatter()
        formatter.calendar = clock.calendar
        formatter.timeZone = clock.calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("d MMMM yyyy")
        return HomeSnapshot(kind: kind, dateLine: formatter.string(from: target))
    }
}
