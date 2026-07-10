import XCTest
@testable import SeenAt
import SwiftUI

final class ColorExtensionTests: XCTestCase {
    func testHex6WithHash() {
        let color = Color(hex: "#FF0000")
        XCTAssertNotNil(color)
        let resolved = color!.resolve(in: .init())
        XCTAssertEqual(resolved.red, 1.0, accuracy: 0.001)
        XCTAssertEqual(resolved.green, 0.0, accuracy: 0.001)
        XCTAssertEqual(resolved.blue, 0.0, accuracy: 0.001)
    }

    func testHex6WithoutHash() {
        let color = Color(hex: "00FF00")
        XCTAssertNotNil(color)
        let resolved = color!.resolve(in: .init())
        XCTAssertEqual(resolved.red, 0.0, accuracy: 0.001)
        XCTAssertEqual(resolved.green, 1.0, accuracy: 0.001)
        XCTAssertEqual(resolved.blue, 0.0, accuracy: 0.001)
    }

    func testHex8WithAlpha() {
        let color = Color(hex: "#FF000080")
        XCTAssertNotNil(color)
        let resolved = color!.resolve(in: .init())
        XCTAssertEqual(resolved.red, 1.0, accuracy: 0.001)
        XCTAssertEqual(resolved.opacity, 128.0 / 255.0, accuracy: 0.01)
    }

    func testInvalidHexReturnsNil() {
        let color = Color(hex: "XYZ")
        XCTAssertNil(color)
    }

    func testEmptyHexReturnsNil() {
        let color = Color(hex: "")
        XCTAssertNil(color)
    }
}
