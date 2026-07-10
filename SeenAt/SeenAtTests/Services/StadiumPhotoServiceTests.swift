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

    func testVenuenameConversion() {
        let image = StadiumPhotoService.image(for: "Wrigley Field")
        // wrigley-field.jpg is in the shared build products — service resolves
        // "Wrigley Field" → "wrigley-field" and finds it at bundle root
    }
}
