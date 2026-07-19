import Foundation

struct EventDateSections {
    let today: [Event]
    let past: [Event]
    let upcoming: [Event]

    var recentPast: [Event] {
        Array(past.prefix(5))
    }

    init(events: [Event], now: Date, calendar: Calendar) {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)!

        past = Self.sort(events.filter { $0.date < startOfToday }, ascending: false)

        today = Self.sort(events.filter { $0.date >= startOfToday && $0.date < startOfTomorrow }, ascending: false)

        upcoming = Self.sort(events.filter { $0.date >= startOfTomorrow }, ascending: true)
    }

    private static func sort(_ events: [Event], ascending: Bool) -> [Event] {
        events.sorted { lhs, rhs in
            if lhs.date != rhs.date {
                return ascending ? lhs.date < rhs.date : lhs.date > rhs.date
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }
}
