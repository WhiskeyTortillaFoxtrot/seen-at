import XCTest
@testable import SeenAt

final class DateParserTests: XCTestCase {

    func testParsesMLBDateFormat() {
        let date = parseISODate("2026-07-09T19:10:00Z")
        XCTAssertNotNil(date)
        let components = utcComponents(from: date!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 7)
        XCTAssertEqual(components.day, 9)
        XCTAssertEqual(components.hour, 19)
        XCTAssertEqual(components.minute, 10)
        XCTAssertEqual(components.second, 0)
    }

    func testParsesESPNDateFormat() {
        let date = parseISODate("2026-07-09T19:10Z")
        XCTAssertNotNil(date)
        let components = utcComponents(from: date!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 7)
        XCTAssertEqual(components.day, 9)
        XCTAssertEqual(components.hour, 19)
        XCTAssertEqual(components.minute, 10)
    }

    func testParsesESPNDateFormatWithSeconds() {
        let date = parseISODate("2026-07-09T19:10:00Z")
        XCTAssertNotNil(date)
        let components = utcComponents(from: date!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 7)
        XCTAssertEqual(components.day, 9)
        XCTAssertEqual(components.hour, 19)
        XCTAssertEqual(components.minute, 10)
    }

    func testParsesNHLDateFormat() {
        let date = parseISODate("2026-07-09")
        XCTAssertNotNil(date)
        let components = utcComponents(from: date!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 7)
        XCTAssertEqual(components.day, 9)
        XCTAssertEqual(components.hour, 0)
        XCTAssertEqual(components.minute, 0)
    }

    func testParsesISO8601WithFractionalSeconds() {
        let date = parseISODate("2026-07-09T19:10:00.123Z")
        XCTAssertNotNil(date)
        let components = utcComponents(from: date!)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 7)
        XCTAssertEqual(components.day, 9)
        XCTAssertEqual(components.hour, 19)
        XCTAssertEqual(components.minute, 10)
    }

    func testReturnsNilForInvalidString() {
        let date = parseISODate("not-a-date")
        XCTAssertNil(date)
    }

    func testReturnsNilForEmptyString() {
        let date = parseISODate("")
        XCTAssertNil(date)
    }

    // MARK: - Helpers

    private func utcComponents(from date: Date) -> (year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        return (
            year: components.year!,
            month: components.month!,
            day: components.day!,
            hour: components.hour!,
            minute: components.minute!,
            second: components.second ?? 0
        )
    }
}
