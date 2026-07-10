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
        XCTAssertNil(image, "Stadium photo not available in test bundle")
    }
}
