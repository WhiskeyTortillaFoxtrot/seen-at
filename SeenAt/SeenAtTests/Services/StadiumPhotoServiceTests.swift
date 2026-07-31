import XCTest
@testable import SeenAt
import SwiftUI

final class StadiumPhotoServiceTests: XCTestCase {
    func testImageNotFoundForUnknownVenue() {
        let image = StadiumPhotoService.image(for: "Nonexistent Stadium")
        XCTAssertNil(image)
    }

    func testImageNotFoundForEmptyName() {
        let image = StadiumPhotoService.image(for: "")
        XCTAssertNil(image)
    }

    func testVenueNameConversionFindsWrigleyField() {
        let image = StadiumPhotoService.image(for: "Wrigley Field")
        // wrigley-field.jpg is in the shared build products — service resolves
        // "Wrigley Field" → "wrigley-field" and finds it at bundle root
        XCTAssertNotNil(image)
    }

    func testVenueNameConversionFindsFenwayPark() {
        let image = StadiumPhotoService.image(for: "Fenway Park")
        XCTAssertNotNil(image)
    }

    func testVenueNameConversionFindsBellCentre() {
        let image = StadiumPhotoService.image(for: "Bell Centre")
        XCTAssertNotNil(image)
    }

    func testHasImageForKnownVenue() {
        XCTAssertTrue(VenueImageService.hasImage(for: "Wrigley Field"))
    }

    func testHasImageForUnknownVenue() {
        XCTAssertFalse(VenueImageService.hasImage(for: "Nonexistent Stadium"))
    }

    func testNormalizeRemovesParentheses() {
        // Normalize strips '(', ')', so "Fenway (Park)" → "fenway-park"
        let image = StadiumPhotoService.image(for: "Fenway (Park)")
        XCTAssertNotNil(image)
    }

    func testImageFoundForNWSLStadiums() {
        let venues = [
            "BMO Stadium",
            "CPKC Stadium",
            "Snapdragon Stadium",
            "Providence Park",
            "Lynn Family Stadium",
            "Audi Field",
            "Red Bull Arena",
            "WakeMed Soccer Park",
        ]
        for venue in venues {
            XCTAssertNotNil(StadiumPhotoService.image(for: venue), "Missing image for \(venue)")
        }
    }
}
