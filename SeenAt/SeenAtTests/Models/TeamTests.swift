import XCTest
@testable import SeenAt
import SwiftUI
@testable import SeenAt

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
}
