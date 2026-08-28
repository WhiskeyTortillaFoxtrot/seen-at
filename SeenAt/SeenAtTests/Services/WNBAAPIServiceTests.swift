import XCTest
@testable import SeenAt

final class WNBAAPIServiceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.requestHandler = nil
        APICacheService.clearCache()
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        APICacheService.clearCache()
        super.tearDown()
    }

    func testFetchGamesMapsCurrentScheduleFeedAndFiltersDate() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url, WNBAAPIService.scheduleURL)
            return (self.response(for: request), Self.scheduleJSON.data(using: .utf8)!)
        }

        let games = try await WNBAAPIService.fetchGames(on: Self.date("2026-06-21"), session: mockSession())

        XCTAssertEqual(games.count, 1)
        XCTAssertEqual(games[0].id, "wnba-1022600042")
        XCTAssertEqual(games[0].awayTeam, "New York Liberty")
        XCTAssertEqual(games[0].homeTeam, "Los Angeles Sparks")
        XCTAssertEqual(games[0].venueName, "Crypto.com Arena")
        XCTAssertEqual(games[0].dateString, "2026-06-21T19:00:00Z")
        XCTAssertEqual(games[0].league, "wnba")
    }

    func testFetchGamesReturnsEmptyArrayForDateOutsideSchedule() async throws {
        MockURLProtocol.requestHandler = { request in
            (self.response(for: request), Self.scheduleJSON.data(using: .utf8)!)
        }

        let games = try await WNBAAPIService.fetchGames(on: Self.date("2026-06-22"), session: mockSession())
        XCTAssertTrue(games.isEmpty)
    }

    func testFetchGamesUsesCacheAfterInitialFetch() async throws {
        let date = Self.date("2026-06-21")
        MockURLProtocol.requestHandler = { request in
            (self.response(for: request), Self.scheduleJSON.data(using: .utf8)!)
        }
        _ = try await WNBAAPIService.fetchGames(on: date, session: mockSession())

        MockURLProtocol.requestHandler = { _ in throw URLError(.notConnectedToInternet) }
        let cachedGames = try await WNBAAPIService.fetchGames(on: date, session: mockSession())

        XCTAssertEqual(cachedGames.count, 1)
        XCTAssertEqual(cachedGames.first?.id, "wnba-1022600042")
    }

    func testFetchGamesThrowsForMalformedPayloadWithoutCache() async {
        MockURLProtocol.requestHandler = { request in
            (self.response(for: request), Data("not json".utf8))
        }

        await XCTAssertThrowsErrorAsync {
            _ = try await WNBAAPIService.fetchGames(on: Self.date("2026-06-21"), session: self.mockSession())
        }
    }

    func testFetchGamesThrowsForUnsuccessfulResponseWithoutCache() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        await XCTAssertThrowsErrorAsync {
            _ = try await WNBAAPIService.fetchGames(on: Self.date("2026-06-21"), session: self.mockSession())
        }
    }

    private func mockSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func response(for request: URLRequest) -> HTTPURLResponse {
        HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
    }

    private static func date(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)!
    }

    private static let scheduleJSON = """
    {
      "leagueSchedule": {
        "gameDates": [
          {
            "gameDate": "2026-06-21",
            "games": [
              {
                "gameId": "1022600042",
                "gameDateTimeUTC": "2026-06-21T19:00:00Z",
                "arenaName": "Crypto.com Arena",
                "awayTeam": { "teamCity": "New York", "teamName": "Liberty" },
                "homeTeam": { "teamCity": "Los Angeles", "teamName": "Sparks" }
              }
            ]
          },
          {
            "gameDate": "2026-06-23",
            "games": []
          }
        ]
      }
    }
    """
}

private func XCTAssertThrowsErrorAsync(
    _ expression: @escaping () async throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await expression()
        XCTFail("Expected an error", file: file, line: line)
    } catch {
        // Expected.
    }
}
