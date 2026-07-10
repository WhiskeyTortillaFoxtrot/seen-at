import XCTest
@testable import SeenAt

final class MLBAPIServiceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MockURLProtocol.requestHandler = nil
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
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
}
