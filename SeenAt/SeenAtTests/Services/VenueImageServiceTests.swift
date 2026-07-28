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

    func testHasImageFindsBundledVenueImage() {
        XCTAssertTrue(VenueImageService.hasImage(for: "Yankee Stadium"))
    }
}
