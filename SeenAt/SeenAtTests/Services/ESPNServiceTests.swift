import XCTest
@testable import SeenAt

final class ESPNServiceTests: XCTestCase {
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

    func testFetchGamesSuccess() async throws {
        let json = """
        {
            "events": [
                {
                    "id": "401234567",
                    "name": "Lakers vs Celtics",
                    "date": "2026-07-09T19:00:00Z",
                    "competitions": [
                        {
                            "venue": { "fullName": "TD Garden" },
                            "competitors": [
                                { "homeAway": "away", "team": { "name": "Los Angeles Lakers" } },
                                { "homeAway": "home", "team": { "name": "Boston Celtics" } }
                            ]
                        }
                    ],
                    "links": [
                        { "web": { "href": "https://www.espn.com/nba/game/_/gameId/401234567" } }
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
        dateFormatter.dateFormat = "yyyyMMdd"
        let date = dateFormatter.date(from: "20260709")!

        let games = try await ESPNService.fetchGames(on: date, sportPath: "basketball/nba", session: mockSession)
        XCTAssertEqual(games.count, 1)
        XCTAssertEqual(games[0].id, "nba-401234567")
        XCTAssertEqual(games[0].title, "Los Angeles Lakers @ Boston Celtics")
        XCTAssertEqual(games[0].awayTeam, "Los Angeles Lakers")
        XCTAssertEqual(games[0].homeTeam, "Boston Celtics")
        XCTAssertEqual(games[0].venueName, "TD Garden")
    }

    func testFetchGamesNetworkError() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: config)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let date = dateFormatter.date(from: "20260709")!

        do {
            _ = try await ESPNService.fetchGames(on: date, sportPath: "basketball/nba", session: mockSession)
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
        dateFormatter.dateFormat = "yyyyMMdd"
        let date = dateFormatter.date(from: "20260709")!

        do {
            _ = try await ESPNService.fetchGames(on: date, sportPath: "basketball/nba", session: mockSession)
            XCTFail("Expected decoding error")
        } catch {
            XCTAssertTrue(error is DecodingError)
        }
    }

    func testLinkIsDecoded() async throws {
        let json = """
        {
            "events": [
                {
                    "id": "401234567",
                    "name": "Lakers vs Celtics",
                    "date": "2026-07-09T19:00:00Z",
                    "competitions": [
                        {
                            "venue": { "fullName": "TD Garden" },
                            "competitors": [
                                { "homeAway": "away", "team": { "name": "Los Angeles Lakers" } },
                                { "homeAway": "home", "team": { "name": "Boston Celtics" } }
                            ]
                        }
                    ],
                    "links": [
                        { "web": { "href": "https://www.espn.com/nba/game/_/gameId/401234567" } }
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
        dateFormatter.dateFormat = "yyyyMMdd"
        let date = dateFormatter.date(from: "20260709")!

        let games = try await ESPNService.fetchGames(on: date, sportPath: "basketball/nba", session: mockSession)
        XCTAssertEqual(games.count, 1)
        XCTAssertEqual(games.first?.url?.absoluteString, "https://www.espn.com/nba/game/_/gameId/401234567")
    }

    func testMissingLinkReturnsNilURL() async throws {
        let json = """
        {
            "events": [
                {
                    "id": "401234567",
                    "name": "Lakers vs Celtics",
                    "date": "2026-07-09T19:00:00Z",
                    "competitions": [
                        {
                            "venue": { "fullName": "TD Garden" },
                            "competitors": [
                                { "homeAway": "away", "team": { "name": "Los Angeles Lakers" } },
                                { "homeAway": "home", "team": { "name": "Boston Celtics" } }
                            ]
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
        dateFormatter.dateFormat = "yyyyMMdd"
        let date = dateFormatter.date(from: "20260709")!

        let games = try await ESPNService.fetchGames(on: date, sportPath: "basketball/nba", session: mockSession)
        XCTAssertEqual(games.count, 1)
        XCTAssertNil(games.first?.url)
    }

    func testFetchGamesReturnsCachedResults() async throws {
        let json = """
        {
            "events": [
                {
                    "id": "401234567",
                    "name": "Lakers vs Celtics",
                    "date": "2026-07-09T19:00:00Z",
                    "competitions": [
                        {
                            "venue": { "fullName": "TD Garden" },
                            "competitors": [
                                { "homeAway": "away", "team": { "name": "Los Angeles Lakers" } },
                                { "homeAway": "home", "team": { "name": "Boston Celtics" } }
                            ]
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
        dateFormatter.dateFormat = "yyyyMMdd"
        let date = dateFormatter.date(from: "20260709")!

        let games1 = try await ESPNService.fetchGames(on: date, sportPath: "basketball/nba", session: mockSession)
        XCTAssertEqual(games1.count, 1)

        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let games2 = try await ESPNService.fetchGames(on: date, sportPath: "basketball/nba", session: mockSession)
        XCTAssertEqual(games2.count, 1)
        XCTAssertEqual(games2.first?.id, "nba-401234567")
    }
}
