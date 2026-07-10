import XCTest
@testable import SeenAt
import SwiftData
@testable import SeenAt

@MainActor
final class EventTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        container = TestModelContainer.create()
        context = container.mainContext
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    func testTotalCountReturnsSightingsCount() {
        let event = TestDataFactory.makeEvent()
        context.insert(event)
        let team = TestDataFactory.makeTeam()
        context.insert(team)

        XCTAssertEqual(event.totalCount, 0)

        let s1 = TestDataFactory.makeSighting(team: team, event: event)
        context.insert(s1)
        XCTAssertEqual(event.totalCount, 1)

        let s2 = TestDataFactory.makeSighting(team: team, event: event)
        context.insert(s2)
        XCTAssertEqual(event.totalCount, 2)
    }

    func testTotalCountUpdatesWhenSightingRemoved() {
        let event = TestDataFactory.makeEvent()
        context.insert(event)
        let team = TestDataFactory.makeTeam()
        context.insert(team)
        let sighting = TestDataFactory.makeSighting(team: team, event: event)
        context.insert(sighting)
        try? context.save()

        XCTAssertEqual(event.totalCount, 1)

        context.delete(sighting)
        try? context.save()
        XCTAssertEqual(event.totalCount, 0)
    }

    func testTeamBreakdownGroupsByTeam() {
        let event = TestDataFactory.makeEvent()
        context.insert(event)
        let teamA = TestDataFactory.makeTeam(name: "Team A", abbreviation: "TA", primaryHex: "#FF0000", secondaryHex: "#000000")
        let teamB = TestDataFactory.makeTeam(name: "Team B", abbreviation: "TB", primaryHex: "#00FF00", secondaryHex: "#000000")
        context.insert(teamA)
        context.insert(teamB)

        let s1 = TestDataFactory.makeSighting(team: teamA, event: event)
        let s2 = TestDataFactory.makeSighting(team: teamA, event: event)
        let s3 = TestDataFactory.makeSighting(team: teamB, event: event)
        context.insert(s1)
        context.insert(s2)
        context.insert(s3)

        let breakdown = event.teamBreakdown
        XCTAssertEqual(breakdown.count, 2)
        XCTAssertEqual(breakdown[0].team.name, "Team A")
        XCTAssertEqual(breakdown[0].count, 2)
        XCTAssertEqual(breakdown[1].team.name, "Team B")
        XCTAssertEqual(breakdown[1].count, 1)
    }

    func testTeamBreakdownSortsByCountDescThenByName() {
        let event = TestDataFactory.makeEvent()
        context.insert(event)
        let teamA = TestDataFactory.makeTeam(name: "Alpha", abbreviation: "ALP")
        let teamB = TestDataFactory.makeTeam(name: "Bravo", abbreviation: "BRA")
        context.insert(teamA)
        context.insert(teamB)

        let s1 = TestDataFactory.makeSighting(team: teamB, event: event)
        let s2 = TestDataFactory.makeSighting(team: teamA, event: event)
        context.insert(s1)
        context.insert(s2)

        let breakdown = event.teamBreakdown
        XCTAssertEqual(breakdown.count, 2)
        XCTAssertEqual(breakdown[0].team.name, "Alpha")
        XCTAssertEqual(breakdown[1].team.name, "Bravo")
    }

    func testPlayerBreakdownFiltersEmptyDisplayNames() {
        let event = TestDataFactory.makeEvent()
        context.insert(event)
        let team = TestDataFactory.makeTeam(name: "Team", abbreviation: "TM")
        context.insert(team)

        let s1 = TestDataFactory.makeSighting(team: team, firstName: "John", lastName: "Doe", event: event)
        let s2 = TestDataFactory.makeSighting(team: team, firstName: nil, lastName: nil, event: event)
        context.insert(s1)
        context.insert(s2)

        let breakdown = event.playerBreakdown
        XCTAssertEqual(breakdown.count, 1)
        XCTAssertEqual(breakdown[0].playerName, "John Doe")
    }

    func testPlayersForTeam() {
        let event = TestDataFactory.makeEvent()
        context.insert(event)
        let teamA = TestDataFactory.makeTeam(name: "Team A", abbreviation: "TA")
        let teamB = TestDataFactory.makeTeam(name: "Team B", abbreviation: "TB")
        context.insert(teamA)
        context.insert(teamB)

        let s1 = TestDataFactory.makeSighting(team: teamA, firstName: "John", event: event)
        let s2 = TestDataFactory.makeSighting(team: teamA, firstName: "John", event: event)
        let s3 = TestDataFactory.makeSighting(team: teamB, firstName: "Jane", event: event)
        context.insert(s1)
        context.insert(s2)
        context.insert(s3)

        let playersA = event.players(for: teamA)
        XCTAssertEqual(playersA.count, 1)
        XCTAssertEqual(playersA[0].playerName, "John")
        XCTAssertEqual(playersA[0].count, 2)

        let playersB = event.players(for: teamB)
        XCTAssertEqual(playersB.count, 1)
        XCTAssertEqual(playersB[0].playerName, "Jane")
    }
}
