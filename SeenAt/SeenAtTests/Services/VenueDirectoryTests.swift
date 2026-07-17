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

    func testAllVenuesPresent() {
        XCTAssertEqual(VenueDirectory.all.count, 141)
    }

    func testHomeVenueMLB() {
        let venue = VenueDirectory.homeVenue(for: "New York Yankees")
        XCTAssertEqual(venue, "Yankee Stadium")
    }

    func testHomeVenueNBA() {
        let venue = VenueDirectory.homeVenue(for: "Los Angeles Lakers")
        XCTAssertEqual(venue, "Crypto.com Arena")
    }

    func testHomeVenueNFL() {
        let venue = VenueDirectory.homeVenue(for: "Green Bay Packers")
        XCTAssertEqual(venue, "Lambeau Field")
    }

    func testHomeVenueNHL() {
        let venue = VenueDirectory.homeVenue(for: "Boston Bruins")
        XCTAssertEqual(venue, "TD Garden")
    }

    func testHomeVenueLOVB() {
        let venue = VenueDirectory.homeVenue(for: "LOVB Nebraska")
        XCTAssertEqual(venue, "Baxter Arena")
    }

    func testHomeVenueMLS() {
        let venue = VenueDirectory.homeVenue(for: "Seattle Sounders FC")
        XCTAssertEqual(venue, "Lumen Field")
    }

    func testHomeVenueSharedNBANHL() {
        let lakers = VenueDirectory.homeVenue(for: "Los Angeles Lakers")
        let clips = VenueDirectory.homeVenue(for: "Los Angeles Clippers")
        let kings = VenueDirectory.homeVenue(for: "Los Angeles Kings")
        XCTAssertEqual(lakers, "Crypto.com Arena")
        XCTAssertEqual(clips, "Crypto.com Arena")
        XCTAssertEqual(kings, "Crypto.com Arena")
    }

    func testHomeVenueSharedNFLNHL() {
        let rangers = VenueDirectory.homeVenue(for: "New York Rangers")
        let knicks = VenueDirectory.homeVenue(for: "New York Knicks")
        XCTAssertEqual(rangers, "Madison Square Garden")
        XCTAssertEqual(knicks, "Madison Square Garden")
    }

    func testHomeVenueUnknown() {
        let venue = VenueDirectory.homeVenue(for: "Nonexistent Team")
        XCTAssertNil(venue)
    }

    func testAllVenuesHaveValidCoordinates() {
        for (name, info) in VenueDirectory.all {
            XCTAssertTrue(info.latitude >= -90 && info.latitude <= 90, "\(name) has invalid latitude: \(info.latitude)")
            XCTAssertTrue(info.longitude >= -180 && info.longitude <= 180, "\(name) has invalid longitude: \(info.longitude)")
            XCTAssertFalse(info.address.isEmpty, "\(name) has empty address")
        }
    }
}
