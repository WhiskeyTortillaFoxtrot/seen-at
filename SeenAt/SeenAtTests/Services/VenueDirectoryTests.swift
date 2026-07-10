import XCTest
@testable import SeenAt

final class VenueDirectoryTests: XCTestCase {
    func testExactMatch() {
        let info = VenueDirectory.info(for: "Yankee Stadium")
        XCTAssertNotNil(info)
        XCTAssertEqual(info?.latitude ?? 0, 40.8296, accuracy: 0.001)
        XCTAssertEqual(info?.longitude ?? 0, -73.9262, accuracy: 0.001)
    }

    func testCaseInsensitiveMatch() {
        let info = VenueDirectory.info(for: "yankee stadium")
        XCTAssertNotNil(info)
        XCTAssertEqual(info?.name, "Yankee Stadium")
    }

    func testUnknownVenue() {
        let info = VenueDirectory.info(for: "Nonexistent Park")
        XCTAssertNil(info)
    }

    func testAllMLBVenuesPresent() {
        let expectedCount = 30
        XCTAssertEqual(VenueDirectory.all.count, expectedCount)
    }

    func testAllVenuesHaveValidCoordinates() {
        for (name, info) in VenueDirectory.all {
            XCTAssertTrue(info.latitude >= -90 && info.latitude <= 90, "\(name) has invalid latitude: \(info.latitude)")
            XCTAssertTrue(info.longitude >= -180 && info.longitude <= 180, "\(name) has invalid longitude: \(info.longitude)")
            XCTAssertFalse(info.address.isEmpty, "\(name) has empty address")
        }
    }
}
