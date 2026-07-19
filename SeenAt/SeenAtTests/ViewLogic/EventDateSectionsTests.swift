import XCTest
@testable import SeenAt

final class EventDateSectionsTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private var referenceDate: Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 18, hour: 12))!
    }

    func testRecentPastIsLimitedToFiveNewestGames() {
        let events = (1...7).map { offset in
            TestDataFactory.makeEvent(
                title: "Game \(offset)",
                date: calendar.date(byAdding: .day, value: -offset, to: referenceDate)!
            )
        }

        let sections = EventDateSections(events: events, now: referenceDate, calendar: calendar)

        XCTAssertEqual(sections.past.count, 7)
        XCTAssertEqual(sections.recentPast.count, 5)
        XCTAssertEqual(sections.recentPast.map(\.title), ["Game 1", "Game 2", "Game 3", "Game 4", "Game 5"])
    }

    func testPastEventsAreNewestFirst() {
        let older = TestDataFactory.makeEvent(title: "Older", date: calendar.date(byAdding: .day, value: -3, to: referenceDate)!)
        let newer = TestDataFactory.makeEvent(title: "Newer", date: calendar.date(byAdding: .day, value: -1, to: referenceDate)!)

        let sections = EventDateSections(events: [older, newer], now: referenceDate, calendar: calendar)

        XCTAssertEqual(sections.past.map(\.title), ["Newer", "Older"])
    }

    func testTodayAndUpcomingEventsAreExcludedFromPast() {
        let today = TestDataFactory.makeEvent(title: "Today", date: referenceDate)
        let tomorrow = TestDataFactory.makeEvent(title: "Tomorrow", date: calendar.date(byAdding: .day, value: 1, to: referenceDate)!)

        let sections = EventDateSections(events: [today, tomorrow], now: referenceDate, calendar: calendar)

        XCTAssertTrue(sections.past.isEmpty)
        XCTAssertEqual(sections.today.map(\.title), ["Today"])
        XCTAssertEqual(sections.upcoming.map(\.title), ["Tomorrow"])
    }

    func testEventJustBeforeTodayIsPast() {
        let event = TestDataFactory.makeEvent(
            title: "Last Night",
            date: calendar.date(byAdding: .second, value: -1, to: calendar.startOfDay(for: referenceDate))!
        )

        let sections = EventDateSections(events: [event], now: referenceDate, calendar: calendar)

        XCTAssertEqual(sections.past.map(\.title), ["Last Night"])
    }

    func testSameDateEventsHaveDeterministicIDTieBreak() {
        let first = TestDataFactory.makeEvent(title: "First", date: referenceDate.addingTimeInterval(-86400))
        let second = TestDataFactory.makeEvent(title: "Second", date: referenceDate.addingTimeInterval(-86400))
        let expected = [first, second].sorted { $0.id.uuidString < $1.id.uuidString }

        let sections = EventDateSections(events: [second, first], now: referenceDate, calendar: calendar)

        XCTAssertEqual(sections.past.map(\.id), expected.map(\.id))
    }
}
