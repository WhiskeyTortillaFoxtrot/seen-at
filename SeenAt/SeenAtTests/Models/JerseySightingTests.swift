import XCTest
@testable import SeenAt
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
}
