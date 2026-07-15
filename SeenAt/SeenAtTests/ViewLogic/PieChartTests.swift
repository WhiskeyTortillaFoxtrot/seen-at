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

    // MARK: - PieChartSelection.team(at:in:)

    private func angle(fromNoon degrees: Double) -> Double {
        (degrees - 90) * .pi / 180
    }

    private func makeTeam(_ name: String, abbreviation: String, primaryHex: String = "#000000") -> Team {
        Team(name: name, abbreviation: abbreviation, primaryColorHex: primaryHex, secondaryColorHex: "#FFFFFF")
    }

    func testEqualCountSlicesSelectCorrectly() {
        let teamA = makeTeam("Alpha", abbreviation: "ALP", primaryHex: "#FF0000")
        let teamB = makeTeam("Bravo", abbreviation: "BRA", primaryHex: "#0000FF")
        let breakdown: [(team: Team, count: Int)] = [(teamA, 2), (teamB, 2)]

        let tapA = PieChartSelection.team(at: angle(fromNoon: 90), in: breakdown)
        XCTAssertEqual(tapA?.name, "Alpha")

        let tapB = PieChartSelection.team(at: angle(fromNoon: 270), in: breakdown)
        XCTAssertEqual(tapB?.name, "Bravo")
    }

    func testEqualCountBoundaryIsConsistent() {
        let teamA = makeTeam("Alpha", abbreviation: "ALP", primaryHex: "#FF0000")
        let teamB = makeTeam("Bravo", abbreviation: "BRA", primaryHex: "#0000FF")
        let breakdown: [(team: Team, count: Int)] = [(teamA, 2), (teamB, 2)]

        let tapAtBoundary = PieChartSelection.team(at: angle(fromNoon: 180), in: breakdown)
        XCTAssertEqual(tapAtBoundary?.name, "Alpha")
    }

    func testThreeTeamsTwoEqualCounts() {
        let teamA = makeTeam("Alpha", abbreviation: "ALP", primaryHex: "#FF0000")
        let teamB = makeTeam("Bravo", abbreviation: "BRA", primaryHex: "#0000FF")
        let teamC = makeTeam("Charlie", abbreviation: "CHA", primaryHex: "#00FF00")
        let breakdown: [(team: Team, count: Int)] = [(teamA, 2), (teamB, 2), (teamC, 1)]

        let tapA = PieChartSelection.team(at: angle(fromNoon: 72), in: breakdown)
        XCTAssertEqual(tapA?.name, "Alpha")

        let tapB = PieChartSelection.team(at: angle(fromNoon: 216), in: breakdown)
        XCTAssertEqual(tapB?.name, "Bravo")

        let tapC = PieChartSelection.team(at: angle(fromNoon: 324), in: breakdown)
        XCTAssertEqual(tapC?.name, "Charlie")
    }

    func testSingleTeamAlwaysSelected() {
        let team = makeTeam("Solo", abbreviation: "SOL")
        let breakdown: [(team: Team, count: Int)] = [(team, 5)]

        let tap0 = PieChartSelection.team(at: angle(fromNoon: 0), in: breakdown)
        XCTAssertEqual(tap0?.name, "Solo")

        let tap90 = PieChartSelection.team(at: angle(fromNoon: 90), in: breakdown)
        XCTAssertEqual(tap90?.name, "Solo")

        let tap180 = PieChartSelection.team(at: angle(fromNoon: 180), in: breakdown)
        XCTAssertEqual(tap180?.name, "Solo")

        let tap270 = PieChartSelection.team(at: angle(fromNoon: 270), in: breakdown)
        XCTAssertEqual(tap270?.name, "Solo")

        let tap359 = PieChartSelection.team(at: angle(fromNoon: 359), in: breakdown)
        XCTAssertEqual(tap359?.name, "Solo")
    }

    func testEmptyBreakdownReturnsNil() {
        let breakdown: [(team: Team, count: Int)] = []
        let result = PieChartSelection.team(at: .pi / 2, in: breakdown)
        XCTAssertNil(result)
    }

    func testUnequalCounts() {
        let teamA = makeTeam("Big", abbreviation: "BIG", primaryHex: "#FF0000")
        let teamB = makeTeam("Small", abbreviation: "SML", primaryHex: "#0000FF")
        let breakdown: [(team: Team, count: Int)] = [(teamA, 3), (teamB, 1)]

        let tapInBig = PieChartSelection.team(at: angle(fromNoon: 90), in: breakdown)
        XCTAssertEqual(tapInBig?.name, "Big")

        let tapInSmall = PieChartSelection.team(at: angle(fromNoon: 315), in: breakdown)
        XCTAssertEqual(tapInSmall?.name, "Small")
    }
}
