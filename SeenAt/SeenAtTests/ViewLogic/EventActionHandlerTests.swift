import XCTest
@testable import SeenAt
import SwiftData
@testable import SeenAt

@MainActor
final class EventActionHandlerTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!
    var event: Event!
    var team: Team!

    override func setUp() {
        super.setUp()
        container = TestModelContainer.create()
        context = container.mainContext
        event = TestDataFactory.makeEvent()
        context.insert(event)
        team = TestDataFactory.makeTeam()
        context.insert(team)
        try? context.save()
    }

    override func tearDown() {
        container = nil
        context = nil
        event = nil
        team = nil
        super.tearDown()
    }

    func testIncrementPlayerCreatesSighting() {
        let reference = TestDataFactory.makeSighting(team: team, firstName: "John", lastName: "Doe", event: event)
        context.insert(reference)
        try? context.save()

        var lastIncrementTimes: [String: Date] = [:]
        EventActionHandler.incrementPlayer(team: team, name: "John Doe", event: event, context: context, lastIncrementTimes: &lastIncrementTimes)

        let sightings = event.sightings.filter { $0.team?.id == team.id && $0.displayName == "John Doe" }
        XCTAssertEqual(sightings.count, 2)
    }

    func testDebounceBlocksRapidIncrements() {
        let reference = TestDataFactory.makeSighting(team: team, firstName: "John", lastName: "Doe", event: event)
        context.insert(reference)
        try? context.save()

        var lastIncrementTimes: [String: Date] = [:]
        let key = "\(team.id):John Doe"
        lastIncrementTimes[key] = Date()

        EventActionHandler.incrementPlayer(team: team, name: "John Doe", event: event, context: context, lastIncrementTimes: &lastIncrementTimes)

        let sightings = event.sightings.filter { $0.team?.id == team.id && $0.displayName == "John Doe" }
        XCTAssertEqual(sightings.count, 1)
    }

    func testDebounceAllowsAfterDelay() {
        let reference = TestDataFactory.makeSighting(team: team, firstName: "John", lastName: "Doe", event: event)
        context.insert(reference)
        try? context.save()

        var lastIncrementTimes: [String: Date] = [:]
        let key = "\(team.id):John Doe"
        lastIncrementTimes[key] = Date().addingTimeInterval(-1)

        EventActionHandler.incrementPlayer(team: team, name: "John Doe", event: event, context: context, lastIncrementTimes: &lastIncrementTimes)

        let sightings = event.sightings.filter { $0.team?.id == team.id && $0.displayName == "John Doe" }
        XCTAssertEqual(sightings.count, 2)
    }

    func testDeletePlayerRemovesAll() {
        let s1 = TestDataFactory.makeSighting(team: team, firstName: "John", lastName: "Doe", event: event)
        let s2 = TestDataFactory.makeSighting(team: team, firstName: "John", lastName: "Doe", event: event)
        context.insert(s1)
        context.insert(s2)
        try? context.save()

        XCTAssertEqual(event.totalCount, 2)

        EventActionHandler.deletePlayer(team: team, name: "John Doe", event: event, context: context)

        let remaining = event.sightings.filter { $0.team?.id == team.id && $0.displayName == "John Doe" }
        XCTAssertEqual(remaining.count, 0)
    }

    func testDeletePlayerNoMatch() {
        let sighting = TestDataFactory.makeSighting(team: team, firstName: "Jane", lastName: "Doe", event: event)
        context.insert(sighting)
        try? context.save()

        EventActionHandler.deletePlayer(team: team, name: "John Doe", event: event, context: context)

        let remaining = event.sightings.filter { $0.team?.id == team.id && $0.displayName == "Jane Doe" }
        XCTAssertEqual(remaining.count, 1)
    }

    func testDisabledForDebounce() {
        var lastIncrementTimes: [String: Date] = [:]
        let key = "\(team.id):John Doe"
        lastIncrementTimes[key] = Date()

        XCTAssertTrue(EventActionHandler.disabledForDebounce(team: team, name: "John Doe", lastIncrementTimes: lastIncrementTimes))
    }

    func testNotDisabledAfterDebounceExpires() {
        var lastIncrementTimes: [String: Date] = [:]
        let key = "\(team.id):John Doe"
        lastIncrementTimes[key] = Date().addingTimeInterval(-1)

        XCTAssertFalse(EventActionHandler.disabledForDebounce(team: team, name: "John Doe", lastIncrementTimes: lastIncrementTimes))
    }
}
