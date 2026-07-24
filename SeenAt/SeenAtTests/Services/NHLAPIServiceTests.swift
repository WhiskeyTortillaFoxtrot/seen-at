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
                            "awayTeam": { "name": { "default": "Boston Bruins" } }
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
                            "awayTeam": { "name": { "default": "Montreal Canadiens" } }
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
                            "awayTeam": { "name": { "default": "Detroit Red Wings" } }
                        }
                    ]
                }
            ]
        }
        """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json.data(using: .utf8)!)
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: config)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.date(from: "2026-07-10")!

        let games = try await NHLAPIService.fetchGames(on: date, session: mockSession)
        XCTAssertEqual(games.count, 1)
        XCTAssertEqual(games[0].id, "nhl-102")
        XCTAssertEqual(games[0].title, "Montreal Canadiens @ Boston Bruins")
        XCTAssertEqual(games[0].awayTeam, "Montreal Canadiens")
        XCTAssertEqual(games[0].homeTeam, "Boston Bruins")
        XCTAssertEqual(games[0].venueName, "TD Garden")
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
                            "awayTeam": { "name": { "default": "Boston Bruins" } }
                        }
                    ]
                }
            ]
        }
        """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json.data(using: .utf8)!)
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: config)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.date(from: "2026-07-15")!

        let games = try await NHLAPIService.fetchGames(on: date, session: mockSession)
        XCTAssertEqual(games.count, 0)
    }

    func testFetchGamesNetworkError() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: config)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.date(from: "2026-07-09")!

        do {
            _ = try await NHLAPIService.fetchGames(on: date, session: mockSession)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is URLError)
        }
    }

    func testFetchGamesMalformedJSON() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, "not json".data(using: .utf8)!)
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: config)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.date(from: "2026-07-09")!

        do {
            _ = try await NHLAPIService.fetchGames(on: date, session: mockSession)
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
                            "gameLink": "https://www.nhl.com/gamecenter/101"
                        }
                    ]
                }
            ]
        }
        """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json.data(using: .utf8)!)
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: config)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.date(from: "2026-07-09")!

        let games1 = try await NHLAPIService.fetchGames(on: date, session: mockSession)
        XCTAssertEqual(games1.count, 1)

        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let games2 = try await NHLAPIService.fetchGames(on: date, session: mockSession)
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
                            "gameLink": "https://www.nhl.com/gamecenter/101"
                        }
                    ]
                }
            ]
        }
        """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json.data(using: .utf8)!)
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: config)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.date(from: "2026-07-09")!

        let games = try await NHLAPIService.fetchGames(on: date, session: mockSession)
        XCTAssertEqual(games.count, 1)

        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let cachedGames = try await NHLAPIService.fetchGames(on: date, session: mockSession)
        XCTAssertEqual(cachedGames.count, 1)
        XCTAssertEqual(cachedGames.first?.id, "nhl-101")
    }

    func testGameLinkIsDecoded() async throws {
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
                            "gameLink": "https://www.nhl.com/gamecenter/101"
                        }
                    ]
                }
            ]
        }
        """

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, json.data(using: .utf8)!)
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: config)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.date(from: "2026-07-09")!

        let games = try await NHLAPIService.fetchGames(on: date, session: mockSession)
        XCTAssertEqual(games.count, 1)
        XCTAssertEqual(games.first?.url?.absoluteString, "https://www.nhl.com/gamecenter/101")
    }
}
