import XCTest
import SwiftData
@testable import SeenAt

@MainActor
final class TeamResolverTests: XCTestCase {
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

    func testTeamsForEventReturnsBothTeams() {
        let yankees = TestDataFactory.makeTeam(name: "New York Yankees", sport: "mlb")
        let sox = TestDataFactory.makeTeam(name: "Boston Red Sox", sport: "mlb")
        context.insert(yankees)
        context.insert(sox)
        try? context.save()

        let event = TestDataFactory.makeEvent(awayTeam: "New York Yankees", homeTeam: "Boston Red Sox")
        context.insert(event)
        try? context.save()

        let teams = TeamResolver.teams(for: event, context: context)
        XCTAssertEqual(teams.count, 2)
        XCTAssertTrue(teams.contains { $0.name == "New York Yankees" })
        XCTAssertTrue(teams.contains { $0.name == "Boston Red Sox" })
    }

    func testTeamsForEventReturnsEmptyWhenNamesMissing() {
        let event = TestDataFactory.makeEvent(awayTeam: "Unknown A", homeTeam: "Unknown B")
        context.insert(event)
        try? context.save()

        let teams = TeamResolver.teams(for: event, context: context)
        XCTAssertTrue(teams.isEmpty)
    }

    func testTeamsForNamesReturnsMatchingTeams() {
        let team = TestDataFactory.makeTeam(name: "Chicago Cubs", sport: "mlb")
        context.insert(team)
        try? context.save()

        let teams = TeamResolver.teams(for: ["Chicago Cubs"], context: context)
        XCTAssertEqual(teams.count, 1)
        XCTAssertEqual(teams.first?.name, "Chicago Cubs")
    }

    func testTeamsForEmptyNamesReturnsEmpty() {
        let teams = TeamResolver.teams(for: [], context: context)
        XCTAssertTrue(teams.isEmpty)
    }
}
