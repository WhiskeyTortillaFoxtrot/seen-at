import XCTest
@testable import SeenAt

final class VenueImageServiceTests: XCTestCase {
    func testNormalizeLowercasesVenueName() {
        XCTAssertEqual(VenueImageService.normalize("Yankee Stadium"), "yankee-stadium")
    }

    func testNormalizeRemovesApostrophes() {
        XCTAssertEqual(VenueImageService.normalize("St. John's"), "st-johns")
    }

    func testNormalizeRemovesPeriodsAndParentheses() {
        XCTAssertEqual(VenueImageService.normalize("O.Co (Coliseum)"), "oco-coliseum")
    }

    func testNormalizeReplacesAmpersands() {
        XCTAssertEqual(VenueImageService.normalize("AT&T Park"), "atandt-park")
    }

    func testNormalizeCollapsesDoubleSpaces() {
        XCTAssertEqual(VenueImageService.normalize("Citi  Field"), "citi-field")
    }

    func testNormalizeCollapsesArbitraryWhitespace() {
        XCTAssertEqual(VenueImageService.normalize("  Citi   \t Field  "), "citi-field")
    }

    func testNormalizeReplacesSpacesWithDashes() {
        XCTAssertEqual(VenueImageService.normalize("Oracle Park"), "oracle-park")
    }

    func testNormalizeHandlesCombinedVenueFormatting() {
        XCTAssertEqual(
            VenueImageService.normalize("St. John's (Field)"),
            "st-johns-field"
        )
    }

    func testHasImageFindsWrappedVenueWithAmpersand() {
        XCTAssertTrue(VenueImageService.hasImage(for: "Inter&Co Stadium"))
    }

    func testHasImageFindsNWSLVenues() {
        let venues = [
            "BMO Stadium",
            "PayPal Park",
            "Gillette Stadium",
            "Northwestern Medicine Field at Martin Stadium",
            "Shell Energy Stadium",
            "CPKC Stadium",
            "Red Bull Arena",
            "WakeMed Soccer Park",
            "Inter&Co Stadium",
            "Providence Park",
            "Lynn Family Stadium",
            "Snapdragon Stadium",
            "Lumen Field",
            "America First Field",
            "Audi Field",
        ]
        for venue in venues {
            XCTAssertTrue(VenueImageService.hasImage(for: venue), "Missing image for \(venue)")
        }
    }

    func testHasImageForUnknownVenue() {
        XCTAssertFalse(VenueImageService.hasImage(for: "Nonexistent Stadium"))
    }
}
