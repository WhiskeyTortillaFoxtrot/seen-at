import XCTest
@testable import SeenAt

@MainActor
final class NWSLTeamsTests: XCTestCase {
    func testHas16Teams() {
        XCTAssertEqual(NWSLTeams.all.count, 16)
    }

    func testAllTeamsAreBuiltIn() {
        XCTAssertTrue(NWSLTeams.all.allSatisfy { $0.isBuiltIn })
    }

    func testAllTeamsHaveNWSLSport() {
        XCTAssertTrue(NWSLTeams.all.allSatisfy { $0.sport == "nwsl" })
    }

    func testAbbreviationsAreUnique() {
        let abbreviations = NWSLTeams.all.map(\.abbreviation)
        XCTAssertEqual(Set(abbreviations).count, abbreviations.count, "NWSL team abbreviations must be unique")
    }

    func testNamesAreUnique() {
        let names = NWSLTeams.all.map(\.name)
        XCTAssertEqual(Set(names).count, names.count, "NWSL team names must be unique")
    }

    func testAllTeamsHaveColors() {
        XCTAssertTrue(NWSLTeams.all.allSatisfy { !$0.primaryColorHex.isEmpty && !$0.secondaryColorHex.isEmpty })
    }

    func testContainsExpectedTeams() {
        let names = Set(NWSLTeams.all.map(\.name))
        XCTAssertTrue(names.contains("Angel City FC"))
        XCTAssertTrue(names.contains("Gotham FC"))
        XCTAssertTrue(names.contains("Kansas City Current"))
        XCTAssertTrue(names.contains("Portland Thorns FC"))
        XCTAssertTrue(names.contains("San Diego Wave FC"))
        XCTAssertTrue(names.contains("Boston Legacy FC"))
        XCTAssertTrue(names.contains("Denver Summit FC"))
    }
}
