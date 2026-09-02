import XCTest
@testable import SeenAt

final class APICacheServiceTests: XCTestCase {
    override func setUp() {
        super.setUp()
        APICacheService.clearCache()
    }

    override func tearDown() {
        APICacheService.clearCache()
        super.tearDown()
    }

    func testSetAndGetCachedGames() {
        let date = Date()
        let games = [
            LeagueGame(
                id: "test-1",
                awayTeam: "Team A",
                homeTeam: "Team B",
                venueName: "Stadium",
                dateString: "2026-07-23",
                league: "mlb",
                url: nil,
                dayNight: nil
            )
        ]

        APICacheService.setCachedGames(games, league: "mlb", date: date)
        let cached = APICacheService.getCachedGames(league: "mlb", date: date)

        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.count, 1)
        XCTAssertEqual(cached?.first?.id, "test-1")
    }

    func testCacheMissReturnsNil() {
        let date = Date()
        let cached = APICacheService.getCachedGames(league: "mlb", date: date)
        XCTAssertNil(cached)
    }

    func testCacheDifferentLeaguesAreIndependent() {
        let date = Date()
        let mlbGames = [
            LeagueGame(id: "mlb-1", awayTeam: "A", homeTeam: "B", venueName: "S", dateString: "2026-07-23", league: "mlb", url: nil, dayNight: nil)
        ]
        let nhlGames = [
            LeagueGame(id: "nhl-1", awayTeam: "C", homeTeam: "D", venueName: "R", dateString: "2026-07-23", league: "nhl", url: nil, dayNight: nil)
        ]

        APICacheService.setCachedGames(mlbGames, league: "mlb", date: date)
        APICacheService.setCachedGames(nhlGames, league: "nhl", date: date)

        XCTAssertEqual(APICacheService.getCachedGames(league: "mlb", date: date)?.count, 1)
        XCTAssertEqual(APICacheService.getCachedGames(league: "nhl", date: date)?.count, 1)
        XCTAssertEqual(APICacheService.getCachedGames(league: "mlb", date: date)?.first?.id, "mlb-1")
        XCTAssertEqual(APICacheService.getCachedGames(league: "nhl", date: date)?.first?.id, "nhl-1")
    }

    func testClearCacheRemovesAllEntries() {
        let date = Date()
        let games = [
            LeagueGame(id: "test-1", awayTeam: "A", homeTeam: "B", venueName: "S", dateString: "2026-07-23", league: "mlb", url: nil, dayNight: nil)
        ]

        APICacheService.setCachedGames(games, league: "mlb", date: date)
        XCTAssertNotNil(APICacheService.getCachedGames(league: "mlb", date: date))

        APICacheService.clearCache()
        XCTAssertNil(APICacheService.getCachedGames(league: "mlb", date: date))
    }

    func testCacheKeyIsConsistent() {
        let date = Date()
        let key1 = APICacheService.cacheKey(league: "mlb", date: date)
        let key2 = APICacheService.cacheKey(league: "mlb", date: date)
        XCTAssertEqual(key1, key2)
    }

    func testCacheKeyDiffersByLeague() {
        let date = Date()
        let key1 = APICacheService.cacheKey(league: "mlb", date: date)
        let key2 = APICacheService.cacheKey(league: "nhl", date: date)
        XCTAssertNotEqual(key1, key2)
    }

    func testCacheTTLIsFiveMinutes() {
        XCTAssertEqual(APICacheService.cacheTTL, 300)
    }

    func testConcurrentCacheAccessDoesNotCrash() async {
        await withTaskGroup(of: Void.self) { group in
            for index in 0..<100 {
                group.addTask {
                    await Task.detached {
                        let date = Date(timeIntervalSince1970: TimeInterval(index) * 86_400)
                        let games = [LeagueGame(
                            id: "game-\(index)",
                            awayTeam: "Away",
                            homeTeam: "Home",
                            venueName: "Venue",
                            dateString: "2026-07-23",
                            league: "mlb",
                            url: nil,
                            dayNight: nil
                        )]
                        APICacheService.setCachedGames(games, league: "mlb", date: date)
                        _ = APICacheService.getCachedGames(league: "mlb", date: date)
                    }.value
                }
            }
        }

        XCTAssertEqual(APICacheService.getCachedGames(
            league: "mlb",
            date: Date(timeIntervalSince1970: 50 * 86_400)
        )?.first?.id, "game-50")
    }

    func testFreshMissAfterTTLExpiry() {
        let date = Date()
        let games = [LeagueGame(id: "fresh-1", awayTeam: "A", homeTeam: "B", venueName: "S", dateString: "2026-07-23", league: "mlb", url: nil, dayNight: nil)]
        APICacheService.setCachedGames(games, league: "mlb", date: date, timestamp: Date().addingTimeInterval(-301))
        XCTAssertNil(APICacheService.getCachedGames(league: "mlb", date: date), "Fresh hit must miss after TTL")
        XCTAssertNotNil(APICacheService.getStaleGames(league: "mlb", date: date), "Expired entry must remain reachable as stale")
    }

    func testStaleWithinWindowReturnsAfterTTL() {
        let date = Date()
        let games = [LeagueGame(id: "stale-1", awayTeam: "A", homeTeam: "B", venueName: "S", dateString: "2026-07-23", league: "mlb", url: nil, dayNight: nil)]
        APICacheService.setCachedGames(games, league: "mlb", date: date, timestamp: Date().addingTimeInterval(-301))
        XCTAssertEqual(APICacheService.getStaleGames(league: "mlb", date: date)?.first?.id, "stale-1")
    }

    func testStaleBeyondWindowEvicted() {
        let date = Date()
        let games = [LeagueGame(id: "old-1", awayTeam: "A", homeTeam: "B", venueName: "S", dateString: "2026-07-23", league: "mlb", url: nil, dayNight: nil)]
        APICacheService.setCachedGames(games, league: "mlb", date: date, timestamp: Date().addingTimeInterval(-(APICacheService.staleWindow + 1)))
        XCTAssertNil(APICacheService.getStaleGames(league: "mlb", date: date), "Entry beyond stale window must be evicted")
        XCTAssertNil(APICacheService.getCachedGames(league: "mlb", date: date))
    }

    func testStaleWindowIsSixHours() {
        XCTAssertEqual(APICacheService.staleWindow, 6 * 60 * 60)
    }

    func testCapPrunesOldestWhenOverLimit() {
        for index in 0..<APICacheService.maxEntries + 1 {
            let date = Date(timeIntervalSince1970: TimeInterval(index) * 86_400)
            let games = [LeagueGame(id: "cap-\(index)", awayTeam: "A", homeTeam: "B", venueName: "S", dateString: "2026-07-23", league: "mlb", url: nil, dayNight: nil)]
            APICacheService.setCachedGames(games, league: "mlb", date: date, timestamp: Date().addingTimeInterval(TimeInterval(index)))
        }
        // Oldest entry (index 0) must have been pruned; newest must remain.
        let oldestDate = Date(timeIntervalSince1970: 0)
        XCTAssertNil(APICacheService.getStaleGames(league: "mlb", date: oldestDate))
        let newestDate = Date(timeIntervalSince1970: TimeInterval(APICacheService.maxEntries) * 86_400)
        XCTAssertNotNil(APICacheService.getStaleGames(league: "mlb", date: newestDate))
    }

    // MARK: - Shared HTTP boundary

    func testValidatedDataSucceedsWithJSON() async throws {
        let url = URL(string: "https://example.com/schedule")!
        let request = APICacheService.makeRequest(url: url)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), "SeenAt/1.0 (iOS)")

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, Data("{\"ok\":true}".utf8))
        }
        let data = try await APICacheService.validatedData(for: request, session: session)
        XCTAssertEqual(String(data: data, encoding: .utf8), "{\"ok\":true}")
    }

    func testValidatedDataRejectsNon2xx() async {
        let url = URL(string: "https://example.com/schedule")!
        let request = APICacheService.makeRequest(url: url)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, Data("not found".utf8))
        }
        do {
            _ = try await APICacheService.validatedData(for: request, session: session)
            XCTFail("Expected badServerResponse for 404")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .badServerResponse)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testValidatedDataRejectsNonJSONMime() async {
        let url = URL(string: "https://example.com/schedule")!
        let request = APICacheService.makeRequest(url: url)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "text/html"])!
            return (response, Data("<html></html>".utf8))
        }
        do {
            _ = try await APICacheService.validatedData(for: request, session: session)
            XCTFail("Expected badServerResponse for non-JSON MIME")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .badServerResponse)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testValidatedDataRejectsOversizePayload() async {
        let url = URL(string: "https://example.com/schedule")!
        let request = APICacheService.makeRequest(url: url)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        let bigData = Data(repeating: 0x41, count: APICacheService.maxValidatedBytes)
        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            return (response, bigData)
        }
        do {
            _ = try await APICacheService.validatedData(for: request, session: session)
            XCTFail("Expected dataLengthExceedsMaximum for oversize payload")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .dataLengthExceedsMaximum)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSessionDisablesCookiesAndCredentialStorage() {
        let config = APICacheService.session.configuration
        XCTAssertEqual(config.httpShouldSetCookies, false)
        XCTAssertNil(config.httpCookieStorage)
        XCTAssertEqual(config.httpCookieAcceptPolicy, .never)
        XCTAssertEqual(config.requestCachePolicy, .reloadIgnoringLocalCacheData)
    }
}
