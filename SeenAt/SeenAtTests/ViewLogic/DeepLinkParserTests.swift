import XCTest
@testable import SeenAt

final class DeepLinkParserTests: XCTestCase {

    private let validUUID = UUID()

    func testValidURL() {
        let url = URL(string: "seenat://live-tracking/\(validUUID)")!
        XCTAssertEqual(DeepLinkParser.parse(url), .success(.liveTracking(validUUID)))
    }

    func testCaseInsensitiveScheme() {
        let url = URL(string: "SEENAT://live-tracking/\(validUUID)")!
        XCTAssertEqual(DeepLinkParser.parse(url), .success(.liveTracking(validUUID)))
    }

    func testCaseInsensitiveHost() {
        let url = URL(string: "seenat://LIVE-TRACKING/\(validUUID)")!
        XCTAssertEqual(DeepLinkParser.parse(url), .success(.liveTracking(validUUID)))
    }

    func testEventSummaryURL() {
        let url = URL(string: "seenat://event-summary/\(validUUID)")!
        XCTAssertEqual(DeepLinkParser.parse(url), .success(.eventSummary(validUUID)))
    }

    func testStatsURL() {
        let url = URL(string: "seenat://stats")!
        XCTAssertEqual(DeepLinkParser.parse(url), .success(.stats))
    }

    func testWrongScheme() {
        let url = URL(string: "http://live-tracking/\(validUUID)")!
        XCTAssertEqual(DeepLinkParser.parse(url), Result.failure(.invalidScheme))
    }

    func testMissingScheme() {
        let url = URL(string: "//live-tracking/\(validUUID)")!
        XCTAssertEqual(DeepLinkParser.parse(url), Result.failure(.invalidScheme))
    }

    func testWrongHost() {
        let url = URL(string: "seenat://games/\(validUUID)")!
        XCTAssertEqual(DeepLinkParser.parse(url), Result.failure(.invalidHost))
    }

    func testMissingHost() {
        let url = URL(string: "seenat:///\(validUUID)")!
        XCTAssertEqual(DeepLinkParser.parse(url), Result.failure(.invalidHost))
    }

    func testInvalidUUID() {
        let url = URL(string: "seenat://live-tracking/not-a-uuid")!
        XCTAssertEqual(DeepLinkParser.parse(url), Result.failure(.invalidUUID))
    }

    func testEmptyPath() {
        let url = URL(string: "seenat://live-tracking/")!
        XCTAssertEqual(DeepLinkParser.parse(url), Result.failure(.invalidUUID))
    }
}
