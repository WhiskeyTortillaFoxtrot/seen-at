import XCTest
@testable import SeenAt

final class EventPreviewPolicyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private var referenceDate: Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 18, hour: 12))!
    }

    func testTodayEventIsNotReadOnlyEvenWhenScheduledLaterToday() {
        let event = TestDataFactory.makeEvent(
            date: calendar.date(byAdding: .hour, value: 4, to: referenceDate)!
        )

        XCTAssertFalse(EventPreviewPolicy.isReadOnly(event, now: referenceDate, calendar: calendar))
    }

    func testTomorrowEventIsReadOnly() {
        let event = TestDataFactory.makeEvent(
            date: calendar.date(byAdding: .day, value: 1, to: referenceDate)!
        )

        XCTAssertTrue(EventPreviewPolicy.isReadOnly(event, now: referenceDate, calendar: calendar))
    }

    func testEventAtStartOfTomorrowIsReadOnly() {
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: referenceDate))!
        let event = TestDataFactory.makeEvent(date: tomorrow)

        XCTAssertTrue(EventPreviewPolicy.isReadOnly(event, now: referenceDate, calendar: calendar))
    }
}
