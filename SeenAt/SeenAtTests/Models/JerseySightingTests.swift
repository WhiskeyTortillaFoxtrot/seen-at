import XCTest
@testable import SeenAt

final class JerseySightingTests: XCTestCase {
    func testDisplayNameFirstAndLast() {
        let sighting = TestDataFactory.makeSighting(firstName: "John", lastName: "Doe")
        XCTAssertEqual(sighting.displayName, "John Doe")
    }

    func testDisplayNameFirstNameOnly() {
        let sighting = TestDataFactory.makeSighting(firstName: "John", lastName: nil)
        XCTAssertEqual(sighting.displayName, "John")
    }

    func testDisplayNameLastNameOnly() {
        let sighting = TestDataFactory.makeSighting(firstName: nil, lastName: "Doe")
        XCTAssertEqual(sighting.displayName, "Doe")
    }

    func testDisplayNameNumberOnly() {
        let sighting = TestDataFactory.makeSighting(firstName: nil, lastName: nil, number: "42")
        XCTAssertEqual(sighting.displayName, "#42")
    }

    func testDisplayNameNameAndNumber() {
        let sighting = TestDataFactory.makeSighting(firstName: "John", lastName: nil, number: "42")
        XCTAssertEqual(sighting.displayName, "John")
    }

    func testDisplayNameEmpty() {
        let sighting = TestDataFactory.makeSighting(firstName: nil, lastName: nil, number: nil)
        XCTAssertEqual(sighting.displayName, "")
    }

    func testIsPlayerSightingWithFirstName() {
        let sighting = TestDataFactory.makeSighting(firstName: "John")
        XCTAssertTrue(sighting.isPlayerSighting)
    }

    func testIsPlayerSightingWithPlayerNumber() {
        let sighting = TestDataFactory.makeSighting(number: "42")
        XCTAssertTrue(sighting.isPlayerSighting)
    }

    func testIsPlayerSightingWithLastNameOnly() {
        let sighting = TestDataFactory.makeSighting(lastName: "Doe")
        XCTAssertTrue(sighting.isPlayerSighting)
    }

    func testIsPlayerSightingAllFieldsNil() {
        let sighting = TestDataFactory.makeSighting()
        XCTAssertFalse(sighting.isPlayerSighting)
    }

    func testIsPlayerSightingEmptyStrings() {
        let sighting = TestDataFactory.makeSighting(firstName: "", lastName: "", number: "")
        XCTAssertFalse(sighting.isPlayerSighting)
    }
}
