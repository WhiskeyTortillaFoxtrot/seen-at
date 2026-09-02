import XCTest
@testable import SeenAt

final class NHLAPIServiceTests: XCTestCase {
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

    private func makeMockSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    private func makeDate(_ string: String) -> Date {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter.date(from: string)!
    }

    private func stubResponse(_ json: String) {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json.data(using: .utf8)!)
        }
    }

    func testFetchGamesReturnsOnlyMatchingDate() async throws {
        let json = """
        {
            "gameWeek": [
                {
                    "date": "2026-07-09",
                    "games": [
                        {
                            "id": 101,
                            "venue": { "default": "Madison Square Garden" },
                            "homeTeam": { "name": { "default": "NY Rangers" } },
                            "awayTeam": { "name": { "default": "Boston Bruins" } },
                            "startTimeUTC": "2026-07-09T23:00:00Z",
                            "gameCenterLink": "/gamecenter/bos-vs-nyr/2026/07/09/2026020101"
                        }
                    ]
                },
                {
                    "date": "2026-07-10",
                    "games": [
                        {
                            "id": 102,
                            "venue": { "default": "TD Garden" },
                            "homeTeam": { "name": { "default": "Boston Bruins" } },
                            "awayTeam": { "name": { "default": "Montreal Canadiens" } },
                            "startTimeUTC": "2026-07-10T23:30:00Z",
                            "gameCenterLink": "/gamecenter/mtl-vs-bos/2026/07/10/2026020102"
                        }
                    ]
                },
                {
                    "date": "2026-07-11",
                    "games": [
                        {
                            "id": 103,
                            "venue": { "default": "Scotiabank Arena" },
                            "homeTeam": { "name": { "default": "Toronto Maple Leafs" } },
                            "awayTeam": { "name": { "default": "Detroit Red Wings" } },
                            "startTimeUTC": "2026-07-11T23:00:00Z",
                            "gameCenterLink": "/gamecenter/det-vs-tor/2026/07/11/2026020103"
                        }
                    ]
                }
            ]
        }
        """

        stubResponse(json)

        let games = try await NHLAPIService.fetchGames(on: makeDate("2026-07-10"), session: makeMockSession())
        XCTAssertEqual(games.count, 1)
        XCTAssertEqual(games[0].id, "nhl-102")
        XCTAssertEqual(games[0].title, "Montreal Canadiens @ Boston Bruins")
        XCTAssertEqual(games[0].awayTeam, "Montreal Canadiens")
        XCTAssertEqual(games[0].homeTeam, "Boston Bruins")
        XCTAssertEqual(games[0].venueName, "TD Garden")
    }

    func testFetchGamesPreservesStartTimeUTC() async throws {
        let json = """
        {
            "gameWeek": [
                {
                    "date": "2026-07-10",
                    "games": [
                        {
                            "id": 102,
                            "venue": { "default": "TD Garden" },
                            "homeTeam": { "name": { "default": "Boston Bruins" } },
                            "awayTeam": { "name": { "default": "Montreal Canadiens" } },
                            "startTimeUTC": "2026-07-10T23:30:00Z",
                            "gameCenterLink": "/gamecenter/mtl-vs-bos/2026/07/10/2026020102"
                        }
                    ]
                }
            ]
        }
        """

        stubResponse(json)

        let games = try await NHLAPIService.fetchGames(on: makeDate("2026-07-10"), session: makeMockSession())
        XCTAssertEqual(games.count, 1)
        // The real UTC start time is carried through so events keep their actual puck-drop
        // instant instead of a synthesized midnight-UTC date.
        XCTAssertEqual(games[0].dateString, "2026-07-10T23:30:00Z")
    }

    func testFetchGamesFallsBackToQueryDateWithoutStartTime() async throws {
        let json = """
        {
            "gameWeek": [
                {
                    "date": "2026-07-09",
                    "games": [
                        {
                            "id": 101,
                            "venue": { "default": "Madison Square Garden" },
                            "homeTeam": { "name": { "default": "NY Rangers" } },
                            "awayTeam": { "name": { "default": "Boston Bruins" } }
                        }
                    ]
                }
            ]
        }
        """

        stubResponse(json)

        let games = try await NHLAPIService.fetchGames(on: makeDate("2026-07-09"), session: makeMockSession())
        XCTAssertEqual(games.count, 1)
        XCTAssertEqual(games[0].dateString, "2026-07-09")
    }

    func testFetchGamesReturnsEmptyWhenDateNotFound() async throws {
        let json = """
        {
            "gameWeek": [
                {
                    "date": "2026-07-09",
                    "games": [
                        {
                            "id": 101,
                            "venue": { "default": "Madison Square Garden" },
                            "homeTeam": { "name": { "default": "NY Rangers" } },
                            "awayTeam": { "name": { "default": "Boston Bruins" } },
                            "startTimeUTC": "2026-07-09T23:00:00Z",
                            "gameCenterLink": "/gamecenter/bos-vs-nyr/2026/07/09/2026020101"
                        }
                    ]
                }
            ]
        }
        """

        stubResponse(json)

        let games = try await NHLAPIService.fetchGames(on: makeDate("2026-07-15"), session: makeMockSession())
        XCTAssertEqual(games.count, 0)
    }

    func testFetchGamesNetworkError() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            _ = try await NHLAPIService.fetchGames(on: makeDate("2026-07-09"), session: makeMockSession())
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is URLError)
        }
    }

    func testFetchGamesMalformedJSON() async {
        stubResponse("not json")

        do {
            _ = try await NHLAPIService.fetchGames(on: makeDate("2026-07-09"), session: makeMockSession())
            XCTFail("Expected decoding error")
        } catch {
            XCTAssertTrue(error is DecodingError)
        }
    }

    func testFetchGamesReturnsCachedResults() async throws {
        let json = """
        {
            "gameWeek": [
                {
                    "date": "2026-07-09",
                    "games": [
                        {
                            "id": 101,
                            "venue": { "default": "Madison Square Garden" },
                            "homeTeam": { "name": { "default": "NY Rangers" } },
                            "awayTeam": { "name": { "default": "Boston Bruins" } },
                            "startTimeUTC": "2026-07-09T23:00:00Z",
                            "gameCenterLink": "/gamecenter/bos-vs-nyr/2026/07/09/2026020101"
                        }
                    ]
                }
            ]
        }
        """

        stubResponse(json)

        let games1 = try await NHLAPIService.fetchGames(on: makeDate("2026-07-09"), session: makeMockSession())
        XCTAssertEqual(games1.count, 1)

        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let games2 = try await NHLAPIService.fetchGames(on: makeDate("2026-07-09"), session: makeMockSession())
        XCTAssertEqual(games2.count, 1)
        XCTAssertEqual(games2.first?.id, "nhl-101")
    }

    func testFetchGamesReturnsCachedOnNetworkError() async throws {
        let json = """
        {
            "gameWeek": [
                {
                    "date": "2026-07-09",
                    "games": [
                        {
                            "id": 101,
                            "venue": { "default": "Madison Square Garden" },
                            "homeTeam": { "name": { "default": "NY Rangers" } },
                            "awayTeam": { "name": { "default": "Boston Bruins" } },
                            "startTimeUTC": "2026-07-09T23:00:00Z",
                            "gameCenterLink": "/gamecenter/bos-vs-nyr/2026/07/09/2026020101"
                        }
                    ]
                }
            ]
        }
        """

        stubResponse(json)

        let games = try await NHLAPIService.fetchGames(on: makeDate("2026-07-09"), session: makeMockSession())
        XCTAssertEqual(games.count, 1)

        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let cachedGames = try await NHLAPIService.fetchGames(on: makeDate("2026-07-09"), session: makeMockSession())
        XCTAssertEqual(cachedGames.count, 1)
        XCTAssertEqual(cachedGames.first?.id, "nhl-101")
    }

    func testGameCenterLinkIsResolvedToAbsoluteURL() async throws {
        let json = """
        {
            "gameWeek": [
                {
                    "date": "2026-07-09",
                    "games": [
                        {
                            "id": 101,
                            "venue": { "default": "Madison Square Garden" },
                            "homeTeam": { "name": { "default": "NY Rangers" } },
                            "awayTeam": { "name": { "default": "Boston Bruins" } },
                            "startTimeUTC": "2026-07-09T23:00:00Z",
                            "gameCenterLink": "/gamecenter/bos-vs-nyr/2026/07/09/2026020101"
                        }
                    ]
                }
            ]
        }
        """

        stubResponse(json)

        let games = try await NHLAPIService.fetchGames(on: makeDate("2026-07-09"), session: makeMockSession())
        XCTAssertEqual(games.count, 1)
        XCTAssertEqual(games.first?.url?.absoluteString, "https://www.nhl.com/gamecenter/bos-vs-nyr/2026/07/09/2026020101")
    }

    func testAbsoluteGameCenterLinkPassesThroughUnchanged() async throws {
        let json = """
        {
            "gameWeek": [
                {
                    "date": "2026-07-09",
                    "games": [
                        {
                            "id": 101,
                            "venue": { "default": "Madison Square Garden" },
                            "homeTeam": { "name": { "default": "NY Rangers" } },
                            "awayTeam": { "name": { "default": "Boston Bruins" } },
                            "startTimeUTC": "2026-07-09T23:00:00Z",
                            "gameCenterLink": "https://www.nhl.com/gamecenter/bos-vs-nyr/2026/07/09/2026020101"
                        }
                    ]
                }
            ]
        }
        """

        stubResponse(json)

        let games = try await NHLAPIService.fetchGames(on: makeDate("2026-07-09"), session: makeMockSession())
        XCTAssertEqual(games.first?.url?.absoluteString, "https://www.nhl.com/gamecenter/bos-vs-nyr/2026/07/09/2026020101")
    }
}
