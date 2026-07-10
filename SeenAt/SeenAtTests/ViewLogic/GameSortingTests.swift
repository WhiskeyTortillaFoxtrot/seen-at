import XCTest
@testable import SeenAt

final class GameSortingTests: XCTestCase {
    func testFavoriteFirst() {
        let games = [
            LeagueGame(id: "1", awayTeam: "Team A", homeTeam: "Team B", venueName: "Park", dateString: "", league: "mlb", url: nil, dayNight: nil),
            LeagueGame(id: "2", awayTeam: "Favorite Team", homeTeam: "Team D", venueName: "Field", dateString: "", league: "mlb", url: nil, dayNight: nil),
        ]

        let sorted = sortedGames(games, favoriteTeamNames: ["Favorite Team"])
        XCTAssertEqual(sorted.count, 2)
        XCTAssertTrue(sorted[0].title.contains("Favorite Team"))
    }

    func testNoFavoriteReturnsOriginalOrder() {
        let games = [
            LeagueGame(id: "1", awayTeam: "Team A", homeTeam: "Team B", venueName: "Park", dateString: "", league: "mlb", url: nil, dayNight: nil),
            LeagueGame(id: "2", awayTeam: "Team C", homeTeam: "Team D", venueName: "Field", dateString: "", league: "mlb", url: nil, dayNight: nil),
        ]

        let sorted = sortedGames(games, favoriteTeamNames: [])
        XCTAssertEqual(sorted[0].id, "1")
        XCTAssertEqual(sorted[1].id, "2")
    }

    func testFavoriteNotPresent() {
        let games = [
            LeagueGame(id: "1", awayTeam: "Team A", homeTeam: "Team B", venueName: "Park", dateString: "", league: "mlb", url: nil, dayNight: nil),
        ]

        let sorted = sortedGames(games, favoriteTeamNames: ["Nonexistent Team"])
        XCTAssertEqual(sorted.count, 1)
        XCTAssertEqual(sorted[0].id, "1")
    }

    func testMultipleFavorites() {
        let games = [
            LeagueGame(id: "1", awayTeam: "Team A", homeTeam: "Team B", venueName: "Park", dateString: "", league: "mlb", url: nil, dayNight: nil),
            LeagueGame(id: "2", awayTeam: "Favorite Team", homeTeam: "Team D", venueName: "Field", dateString: "", league: "mlb", url: nil, dayNight: nil),
            LeagueGame(id: "3", awayTeam: "Team E", homeTeam: "Other Fav", venueName: "Stadium", dateString: "", league: "mlb", url: nil, dayNight: nil),
        ]

        let sorted = sortedGames(games, favoriteTeamNames: ["Favorite Team", "Other Fav"])
        XCTAssertEqual(sorted.count, 3)
        XCTAssertTrue(sorted[0].title.contains("Favorite Team") || sorted[0].title.contains("Other Fav"))
        XCTAssertTrue(sorted[1].title.contains("Favorite Team") || sorted[1].title.contains("Other Fav"))
    }
}
