import XCTest
@testable import SeenAt
import SwiftData
@testable import SeenAt

@MainActor
final class EventLifecycleTests: XCTestCase {
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

    func testCreateEventAddSightingsAndVerifySummary() {
        let event = TestDataFactory.makeEvent(title: "Yankees @ Red Sox", venue: "Yankee Stadium")
        context.insert(event)

        let teamA = TestDataFactory.makeTeam(name: "New York Yankees", abbreviation: "NYY")
        let teamB = TestDataFactory.makeTeam(name: "Boston Red Sox", abbreviation: "BOS")
        context.insert(teamA)
        context.insert(teamB)

        let s1 = TestDataFactory.makeSighting(team: teamA, firstName: "Derek", lastName: "Jeter", number: "2", event: event)
        let s2 = TestDataFactory.makeSighting(team: teamA, firstName: "Derek", lastName: "Jeter", number: "2", event: event)
        let s3 = TestDataFactory.makeSighting(team: teamB, firstName: "David", lastName: "Ortiz", number: "34", event: event)
        context.insert(s1)
        context.insert(s2)
        context.insert(s3)
        try? context.save()

        XCTAssertEqual(event.totalCount, 3)

        let teamBreakdown = event.teamBreakdown
        XCTAssertEqual(teamBreakdown.count, 2)
        XCTAssertEqual(teamBreakdown[0].team.name, "New York Yankees")
        XCTAssertEqual(teamBreakdown[0].count, 2)
        XCTAssertEqual(teamBreakdown[1].team.name, "Boston Red Sox")
        XCTAssertEqual(teamBreakdown[1].count, 1)

        let playerBreakdown = event.playerBreakdown
        XCTAssertEqual(playerBreakdown.count, 2)

        let yankeePlayers = event.players(for: teamA)
        XCTAssertEqual(yankeePlayers.count, 1)
        XCTAssertEqual(yankeePlayers[0].playerName, "Derek Jeter")
        XCTAssertEqual(yankeePlayers[0].count, 2)

        let summary = ExportService.generateSummary(for: event)
        XCTAssertTrue(summary.contains("Yankees @ Red Sox"))
        XCTAssertTrue(summary.contains("Yankee Stadium"))

        let csv = ExportService.generateAllDataCSV(context: context)
        XCTAssertTrue(csv.contains("New York Yankees"))
        XCTAssertTrue(csv.contains("Boston Red Sox"))
    }

    func testCreateAndClearAllData() {
        let event = TestDataFactory.makeEvent()
        context.insert(event)
        let team = TestDataFactory.makeTeam()
        context.insert(team)
        let sighting = TestDataFactory.makeSighting(team: team, event: event)
        context.insert(sighting)
        try? context.save()

        let allEvents = try! context.fetch(FetchDescriptor<Event>())
        for e in allEvents {
            for s in e.sightings {
                context.delete(s)
            }
            context.delete(e)
        }
        try? context.save()

        let events = try! context.fetch(FetchDescriptor<Event>())
        let sightings = try! context.fetch(FetchDescriptor<JerseySighting>())
        XCTAssertEqual(events.count, 0)
        XCTAssertEqual(sightings.count, 0)
    }

    func testFullHomeViewWorkflow() {
        let today = Date()
        let event1 = TestDataFactory.makeEvent(title: "Today's Game", date: today)
        context.insert(event1)
        let event2 = TestDataFactory.makeEvent(title: "Past Game", date: today.addingTimeInterval(-86400 * 2))
        context.insert(event2)
        try? context.save()

        XCTAssertTrue(Calendar.current.isDateInToday(event1.date))
        XCTAssertFalse(Calendar.current.isDateInToday(event2.date))

        let allEvents = try! context.fetch(FetchDescriptor<Event>(sortBy: [SortDescriptor(\.date, order: .reverse)]))
        XCTAssertEqual(allEvents.count, 2)
    }
}
