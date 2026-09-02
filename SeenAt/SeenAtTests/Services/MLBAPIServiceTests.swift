import XCTest
@testable import SeenAt

final class MLBAPIServiceTests: XCTestCase {
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
            "dates": [
                {
                    "games": [
                        {
                            "gamePk": 12345,
                            "gameDate": "2026-07-09T19:10:00Z",
                            "teams": {
                                "away": { "team": { "id": 1, "name": "Team A" } },
                                "home": { "team": { "id": 2, "name": "Team B" } }
                            },
                            "venue": { "id": 100, "name": "Test Park" },
                            "dayNight": "night",
                            "status": {
                                "abstractGameState": "Preview",
                                "detailedState": "Scheduled",
                                "statusCode": "S"
                            }
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

        let games = try await MLBAPIService.fetchGames(on: date, session: mockSession)
        XCTAssertEqual(games.count, 1)
        XCTAssertEqual(games[0].id, "mlb-12345")
        XCTAssertEqual(games[0].title, "Team A @ Team B")
        XCTAssertEqual(games[0].awayTeam, "Team A")
        XCTAssertEqual(games[0].homeTeam, "Team B")
        XCTAssertEqual(games[0].venueName, "Test Park")
        XCTAssertEqual(games[0].dayNight, "night")
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
            _ = try await MLBAPIService.fetchGames(on: date, session: mockSession)
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
            _ = try await MLBAPIService.fetchGames(on: date, session: mockSession)
            XCTFail("Expected decoding error")
        } catch {
            XCTAssertTrue(error is DecodingError)
        }
    }

    func testFetchGamesReturnsCachedResults() async throws {
        let json = """
        {
            "dates": [
                {
                    "games": [
                        {
                            "gamePk": 12345,
                            "gameDate": "2026-07-09T19:10:00Z",
                            "teams": {
                                "away": { "team": { "id": 1, "name": "Team A" } },
                                "home": { "team": { "id": 2, "name": "Team B" } }
                            },
                            "venue": { "id": 100, "name": "Test Park" },
                            "dayNight": "night",
                            "status": {
                                "abstractGameState": "Preview",
                                "detailedState": "Scheduled",
                                "statusCode": "S"
                            }
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

        let games1 = try await MLBAPIService.fetchGames(on: date, session: mockSession)
        XCTAssertEqual(games1.count, 1)

        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let games2 = try await MLBAPIService.fetchGames(on: date, session: mockSession)
        XCTAssertEqual(games2.count, 1)
        XCTAssertEqual(games2.first?.id, "mlb-12345")
    }

    func testFetchGamesOfflineFallback() async {
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
            _ = try await MLBAPIService.fetchGames(on: date, session: mockSession)
            XCTFail("Expected error to be thrown")
        } catch {
            XCTAssertTrue(error is URLError)
        }
    }

    func testFetchGamesReturnsCachedOnNetworkError() async throws {
        let json = """
        {
            "dates": [
                {
                    "games": [
                        {
                            "gamePk": 12345,
                            "gameDate": "2026-07-09T19:10:00Z",
                            "teams": {
                                "away": { "team": { "id": 1, "name": "Team A" } },
                                "home": { "team": { "id": 2, "name": "Team B" } }
                            },
                            "venue": { "id": 100, "name": "Test Park" },
                            "dayNight": "night",
                            "status": {
                                "abstractGameState": "Preview",
                                "detailedState": "Scheduled",
                                "statusCode": "S"
                            }
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

        let games = try await MLBAPIService.fetchGames(on: date, session: mockSession)
        XCTAssertEqual(games.count, 1)

        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let cachedGames = try await MLBAPIService.fetchGames(on: date, session: mockSession)
        XCTAssertEqual(cachedGames.count, 1)
        XCTAssertEqual(cachedGames.first?.id, "mlb-12345")
    }

    func testStaleCacheReturnedAfterTTLWithNetworkFailure() async throws {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.date(from: "2026-07-09")!

        let staleGames = [LeagueGame(id: "mlb-999", awayTeam: "A", homeTeam: "B", venueName: "S", dateString: "2026-07-09", league: "mlb", url: nil, dayNight: nil)]
        APICacheService.setCachedGames(staleGames, league: "mlb", date: date, timestamp: Date().addingTimeInterval(-400))

        MockURLProtocol.requestHandler = { _ in throw URLError(.notConnectedToInternet) }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: config)

        let games = try await MLBAPIService.fetchGames(on: date, session: mockSession)
        XCTAssertEqual(games.first?.id, "mlb-999", "Expired entry within 6h stale window must be returned on network failure")
    }

    func testStaleBeyondWindowNotReturned() async {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.date(from: "2026-07-09")!

        let oldGames = [LeagueGame(id: "mlb-old", awayTeam: "A", homeTeam: "B", venueName: "S", dateString: "2026-07-09", league: "mlb", url: nil, dayNight: nil)]
        APICacheService.setCachedGames(oldGames, league: "mlb", date: date, timestamp: Date().addingTimeInterval(-(APICacheService.staleWindow + 100)))

        MockURLProtocol.requestHandler = { _ in throw URLError(.notConnectedToInternet) }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: config)

        do {
            _ = try await MLBAPIService.fetchGames(on: date, session: mockSession)
            XCTFail("Expected throw when stale beyond window")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .notConnectedToInternet)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testHTTPStatusValidationRejectsNon2xx() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, Data("{\"error\":true}".utf8))
        }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: config)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let date = dateFormatter.date(from: "2026-07-09")!
        do {
            _ = try await MLBAPIService.fetchGames(on: date, session: mockSession)
            XCTFail("Expected badServerResponse for 500")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .badServerResponse)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
