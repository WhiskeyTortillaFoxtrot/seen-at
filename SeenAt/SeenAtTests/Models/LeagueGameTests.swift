import XCTest
@testable import SeenAt

final class LeagueGameTests: XCTestCase {
    private let base = URL(string: "https://www.nhl.com")!

    func testResolveGameLinkResolvesRelativePathAgainstBase() {
        let url = LeagueGame.resolveGameLink("/gamecenter/bos-vs-nyr/2026/07/09/2026020101", base: base)
        XCTAssertEqual(url?.absoluteString, "https://www.nhl.com/gamecenter/bos-vs-nyr/2026/07/09/2026020101")
    }

    func testResolveGameLinkPassesAbsoluteURLThrough() {
        let url = LeagueGame.resolveGameLink("https://www.espn.com/nhl/game/_/id/401234567", base: base)
        XCTAssertEqual(url?.absoluteString, "https://www.espn.com/nhl/game/_/id/401234567")
    }

    func testResolveGameLinkReturnsNilForNilAndEmptyInput() {
        XCTAssertNil(LeagueGame.resolveGameLink(nil, base: base))
        XCTAssertNil(LeagueGame.resolveGameLink("", base: base))
    }

    func testResolveGameLinkReturnsNilForUnparseableInput() {
        XCTAssertNil(LeagueGame.resolveGameLink("not a url <", base: base))
        XCTAssertNil(LeagueGame.resolveGameLink("gamecenter/relative-without-slash", base: base))
    }

    func testResolveGameLinkRejectsProtocolRelativeLinksThatEscapeTheLeagueDomain() {
        XCTAssertNil(LeagueGame.resolveGameLink("//evil.example.com/game", base: base))
    }
}
