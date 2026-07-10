import XCTest
@testable import SeenAt

final class CreditEntryTests: XCTestCase {
    func testExtractsTitleAndBody() {
        let entry = CreditEntry(
            identifier: "fenway-park",
            creditText: "**Fenway Park** Photo by [Test](https://example.com)"
        )
        XCTAssertEqual(entry.title, "Fenway Park")
        XCTAssertEqual(entry.body, "Photo by [Test](https://example.com)")
    }

    func testNoBoldReturnsEmptyTitle() {
        let entry = CreditEntry(
            identifier: "test",
            creditText: "Photo by Someone"
        )
        XCTAssertEqual(entry.title, "")
        XCTAssertEqual(entry.body, "Photo by Someone")
    }

    func testBoldAtEnd() {
        let entry = CreditEntry(
            identifier: "test",
            creditText: "Text before **Bold Title**"
        )
        XCTAssertEqual(entry.title, "Bold Title")
        XCTAssertEqual(entry.body, "")
    }

    func testMultipleBoldSections() {
        let entry = CreditEntry(
            identifier: "test",
            creditText: "**First Bold** middle **Second Bold** rest"
        )
        XCTAssertEqual(entry.title, "First Bold")
        XCTAssertEqual(entry.body, "middle **Second Bold** rest")
    }

    func testRealWorldFormat() {
        let entry = CreditEntry(
            identifier: "bell-centre",
            creditText: "**Bell Centre** Photo by [Amaury TRAVER](https://unsplash.com/@beyondreality) on [Unsplash](https://unsplash.com/photos/425oIpJ1nWA)"
        )
        XCTAssertEqual(entry.title, "Bell Centre")
        XCTAssertEqual(entry.body, "Photo by [Amaury TRAVER](https://unsplash.com/@beyondreality) on [Unsplash](https://unsplash.com/photos/425oIpJ1nWA)")
    }
}
