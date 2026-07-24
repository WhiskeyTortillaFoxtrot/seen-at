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
}
