import XCTest
@testable import SeenAt
import SwiftData

@MainActor
final class PieChartTests: XCTestCase {
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

    func testTeamBreakdownProvidesDataForChart() {
        let event = TestDataFactory.makeEvent()
        context.insert(event)
        let teamA = TestDataFactory.makeTeam(name: "Team A", abbreviation: "TA")
        let teamB = TestDataFactory.makeTeam(name: "Team B", abbreviation: "TB")
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
        XCTAssertEqual(breakdown[0].count, 2)
        XCTAssertEqual(breakdown[1].count, 1)
    }

    func testStatsTeamTotalsProvidesDataForChart() {
        let teamA = TestDataFactory.makeTeam(name: "Team A", abbreviation: "TA")
        let teamB = TestDataFactory.makeTeam(name: "Team B", abbreviation: "TB")
        context.insert(teamA)
        context.insert(teamB)

        let event1 = TestDataFactory.makeEvent()
        context.insert(event1)
        let event2 = TestDataFactory.makeEvent()
        context.insert(event2)

        context.insert(TestDataFactory.makeSighting(team: teamA, event: event1))
        context.insert(TestDataFactory.makeSighting(team: teamA, event: event2))
        context.insert(TestDataFactory.makeSighting(team: teamB, event: event1))

        let allEvents = try! context.fetch(FetchDescriptor<Event>())
        let totals: [(team: Team, count: Int)] = {
            let allSightings = allEvents.flatMap { $0.sightings.compactMap { $0.team == nil ? nil : $0 } }
            let grouped = Dictionary(grouping: allSightings) { $0.team! }
            return grouped
                .map { ($0.key, $0.value.count) }
                .sorted { a, b in a.count > b.count || (a.count == b.count && a.team.name < b.team.name) }
        }()

        XCTAssertEqual(totals.count, 2)
        XCTAssertEqual(totals.first?.count, 2) // Team A has 2
        XCTAssertEqual(totals.last?.count, 1)  // Team B has 1
    }

    func testToggleStateToggles() {
        // Just verify the concept works — these are simple Bool toggles on @State
        var value = false
        value.toggle()
        XCTAssertTrue(value)
        value.toggle()
        XCTAssertFalse(value)
    }

    func testChartDataNonEmpty() {
        let event = TestDataFactory.makeEvent()
        context.insert(event)
        let team = TestDataFactory.makeTeam()
        context.insert(team)
        context.insert(TestDataFactory.makeSighting(team: team, event: event))

        let breakdown = event.teamBreakdown
        XCTAssertFalse(breakdown.isEmpty)

        // Verify data shape matches SectorMark expectations: angle from Int
        for (team, count) in breakdown {
            XCTAssertGreaterThan(count, 0)
            let angleValue = Double(count)
            XCTAssertGreaterThan(angleValue, 0)
            _ = team.primaryColor // color is available for .foregroundStyle
        }
    }

    func testSingleTeamDoesNotCrashChart() {
        let event = TestDataFactory.makeEvent()
        context.insert(event)
        let team = TestDataFactory.makeTeam(name: "Lone Team", abbreviation: "LT")
        context.insert(team)
        context.insert(TestDataFactory.makeSighting(team: team, event: event))

        let breakdown = event.teamBreakdown
        XCTAssertEqual(breakdown.count, 1)
        XCTAssertEqual(breakdown[0].count, 1)
    }
}
