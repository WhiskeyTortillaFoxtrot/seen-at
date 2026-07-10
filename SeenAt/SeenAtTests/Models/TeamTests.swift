import XCTest
@testable import SeenAt
import SwiftUI

final class TeamTests: XCTestCase {
    func testPrimaryColorValidHex() {
        let team = TestDataFactory.makeTeam(primaryHex: "#A71930")
        let color = team.primaryColor
        let resolved = color.resolve(in: .init())
        XCTAssertEqual(resolved.red, 167.0 / 255.0, accuracy: 0.001)
        XCTAssertEqual(resolved.green, 25.0 / 255.0, accuracy: 0.001)
        XCTAssertEqual(resolved.blue, 48.0 / 255.0, accuracy: 0.001)
    }

    func testPrimaryColorInvalidHexFallsBackToGray() {
        let team = TestDataFactory.makeTeam(primaryHex: "not-a-color")
        let color = team.primaryColor
        let resolved = color.resolve(in: .init())
        XCTAssertEqual(resolved.red, resolved.green, accuracy: 0.05)
        XCTAssertEqual(resolved.green, resolved.blue, accuracy: 0.05)
    }

    func testSecondaryColorValidHex() {
        let team = TestDataFactory.makeTeam(secondaryHex: "#041E42")
        let color = team.secondaryColor
        let resolved = color.resolve(in: .init())
        XCTAssertEqual(resolved.red, 4.0 / 255.0, accuracy: 0.001)
        XCTAssertEqual(resolved.green, 30.0 / 255.0, accuracy: 0.001)
        XCTAssertEqual(resolved.blue, 66.0 / 255.0, accuracy: 0.001)
    }

    func testSportIconMLB() {
        let team = TestDataFactory.makeTeam(sport: "mlb")
        XCTAssertEqual(team.sportIcon, "baseball.fill")
        XCTAssertEqual(Team.sportIcon(for: "mlb"), "baseball.fill")
    }

    func testSportIconNBA() {
        XCTAssertEqual(Team.sportIcon(for: "nba"), "basketball.fill")
    }

    func testSportIconNFL() {
        XCTAssertEqual(Team.sportIcon(for: "nfl"), "football.fill")
    }

    func testSportIconNHL() {
        XCTAssertEqual(Team.sportIcon(for: "nhl"), "hockey.puck.fill")
    }

    func testSportIconLOVB() {
        XCTAssertEqual(Team.sportIcon(for: "lovb"), "volleyball.fill")
    }

    func testSportIconMLS() {
        XCTAssertEqual(Team.sportIcon(for: "mls"), "soccerball.inverse")
    }

    func testSportIconDefault() {
        XCTAssertEqual(Team.sportIcon(for: "unknown"), "questionmark.circle.fill")
    }
}
