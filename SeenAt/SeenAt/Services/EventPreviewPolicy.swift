import Foundation

enum EventPreviewPolicy {
    static func isReadOnly(_ event: Event, now: Date = .now, calendar: Calendar = .current) -> Bool {
        calendar.startOfDay(for: event.date) > calendar.startOfDay(for: now)
    }
}
