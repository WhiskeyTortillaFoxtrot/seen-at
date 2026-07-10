import XCTest
@testable import SeenAt
import SwiftData

@MainActor
final class TeamSortingTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    var allTeams: [Team]!

    override func setUp() {
        super.setUp()
        container = TestModelContainer.create()
        context = container.mainContext
        allTeams = [
            TestDataFactory.makeTeam(name: "Team A", abbreviation: "TA"),
            TestDataFactory.makeTeam(name: "Team B", abbreviation: "TB"),
            TestDataFactory.makeTeam(name: "Team C", abbreviation: "TC"),
        ]
        allTeams.forEach { context.insert($0) }
        try? context.save()
    }

    override func tearDown() {
        container = nil
        context = nil
        allTeams = nil
        super.tearDown()
    }

    func testGameTeamsFirst() {
        let sorted = sortedTeams(allTeams, searchText: "", awayTeam: "Team C", homeTeam: "Team A", favoriteTeamNames: [])
        XCTAssertEqual(sorted.count, 3)
        XCTAssertEqual(sorted[0].name, "Team C")
        XCTAssertEqual(sorted[1].name, "Team A")
    }

    func testFavoriteAtTopIfNotGameTeam() {
        let sorted = sortedTeams(allTeams, searchText: "", awayTeam: "Team A", homeTeam: "Team B", favoriteTeamNames: ["Team C"])
        XCTAssertEqual(sorted.count, 3)
        XCTAssertEqual(sorted[0].name, "Team A") // game team first
        XCTAssertEqual(sorted[1].name, "Team B") // game team second
        XCTAssertEqual(sorted[2].name, "Team C") // favorite after game teams
    }

    func testFavoriteInGameTeams() {
        let sorted = sortedTeams(allTeams, searchText: "", awayTeam: "Team C", homeTeam: "Team A", favoriteTeamNames: ["Team C"])
        XCTAssertEqual(sorted.count, 3)
        XCTAssertEqual(sorted[0].name, "Team C") // favorite is also a game team
        XCTAssertEqual(sorted[1].name, "Team A") // other game team
    }

    func testSearchFilter() {
        let sorted = sortedTeams(allTeams, searchText: "Team A", awayTeam: "Team X", homeTeam: "Team Y", favoriteTeamNames: [])
        XCTAssertEqual(sorted.count, 1)
        XCTAssertEqual(sorted[0].name, "Team A")
    }

    func testEmptySearchReturnsAll() {
        let sorted = sortedTeams(allTeams, searchText: "", awayTeam: "X", homeTeam: "Y", favoriteTeamNames: [])
        XCTAssertEqual(sorted.count, 3)
    }

    func testMultipleFavorites() {
        let sorted = sortedTeams(allTeams, searchText: "", awayTeam: "Team A", homeTeam: "Team B", favoriteTeamNames: ["Team C", "Team B"])
        XCTAssertEqual(sorted.count, 3)
        XCTAssertEqual(sorted[0].name, "Team B") // favorite in game first
        XCTAssertEqual(sorted[1].name, "Team A") // other game team
        XCTAssertEqual(sorted[2].name, "Team C") // favorite not in game
    }
}
