import XCTest
@testable import SeenAt
import SwiftData

@MainActor
final class SwiftDataCRUDTests: XCTestCase {
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

    func testCreateAndFetchEvent() {
        let event = TestDataFactory.makeEvent(title: "Test Event")
        context.insert(event)
        try? context.save()

        let descriptor = FetchDescriptor<Event>()
        let events = try! context.fetch(descriptor)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].title, "Test Event")
    }

    func testUpdateEvent() {
        let event = TestDataFactory.makeEvent(title: "Original")
        context.insert(event)
        try? context.save()

        event.title = "Updated"
        try? context.save()

        let descriptor = FetchDescriptor<Event>()
        let events = try! context.fetch(descriptor)
        XCTAssertEqual(events[0].title, "Updated")
    }

    func testDeleteEventCascadesToSightings() {
        let event = TestDataFactory.makeEvent()
        context.insert(event)
        let team = TestDataFactory.makeTeam()
        context.insert(team)
        let sighting = TestDataFactory.makeSighting(team: team, event: event)
        context.insert(sighting)
        try? context.save()

        context.delete(event)
        try? context.save()

        let sightings = try! context.fetch(FetchDescriptor<JerseySighting>())
        XCTAssertEqual(sightings.count, 0)
    }

    func testDeleteTeamCascadesToSightings() {
        let event = TestDataFactory.makeEvent()
        context.insert(event)
        let team = TestDataFactory.makeTeam()
        context.insert(team)
        let sighting = TestDataFactory.makeSighting(team: team, event: event)
        context.insert(sighting)
        try? context.save()

        context.delete(team)
        try? context.save()

        let sightings = try! context.fetch(FetchDescriptor<JerseySighting>())
        XCTAssertEqual(sightings.count, 0)
    }

    func testUniqueTeamNameConstraint() {
        let sqliteContainer = TestModelContainer.createSQLite()
        let sqliteContext = sqliteContainer.mainContext

        let team1 = TestDataFactory.makeTeam(name: "Same Name")
        sqliteContext.insert(team1)
        try? sqliteContext.save()

        let team2 = TestDataFactory.makeTeam(name: "Same Name")
        sqliteContext.insert(team2)

        XCTAssertThrowsError(try sqliteContext.save())

        TestModelContainer.cleanupSQLite(sqliteContainer)
    }

    func testMultipleSightingsSameEventSameTeam() {
        let event = TestDataFactory.makeEvent()
        context.insert(event)
        let team = TestDataFactory.makeTeam()
        context.insert(team)

        for _ in 0..<5 {
            let sighting = TestDataFactory.makeSighting(team: team, event: event)
            context.insert(sighting)
        }
        try? context.save()

        XCTAssertEqual(event.totalCount, 5)
        XCTAssertEqual(event.teamBreakdown.first?.count, 5)
    }
}
