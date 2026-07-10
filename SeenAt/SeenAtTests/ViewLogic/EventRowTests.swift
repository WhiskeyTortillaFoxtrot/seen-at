import XCTest
@testable import SeenAt

final class EventRowTests: XCTestCase {
    func testParsesAwayAndHomeTeam() {
        let event = TestDataFactory.makeEvent(title: "NYY @ BOS")
        let row = EventRow(event: event)
        XCTAssertEqual(row.awayTeamName, "NYY")
        XCTAssertEqual(row.homeTeamName, "@ BOS")
    }

    func testParsesSingleTeamTitle() {
        let event = TestDataFactory.makeEvent(title: "Exhibition Game")
        let row = EventRow(event: event)
        XCTAssertEqual(row.awayTeamName, "Exhibition Game")
        XCTAssertEqual(row.homeTeamName, "")
    }

    func testParsesEmptyTitle() {
        let event = TestDataFactory.makeEvent(title: "")
        let row = EventRow(event: event)
        XCTAssertEqual(row.awayTeamName, "")
        XCTAssertEqual(row.homeTeamName, "")
    }

    func testParsesTitleWithAtSymbolInName() {
        let event = TestDataFactory.makeEvent(title: "ATL @ NYM")
        let row = EventRow(event: event)
        XCTAssertEqual(row.awayTeamName, "ATL")
        XCTAssertEqual(row.homeTeamName, "@ NYM")
    }

    func testLeadingColorFromFirstTeam() {
        let event = TestDataFactory.makeEvent(title: "CHC @ STL")
        let row = EventRow(event: event)
        XCTAssertEqual(row.leadingColor, .blue) // no teams seeded, falls back to .blue
    }
}
