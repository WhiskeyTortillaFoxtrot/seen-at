import XCTest
@testable import SeenAt
import SwiftData

@MainActor
final class SettingsServiceTests: XCTestCase {
    func testDeleteAllSightingsRemovesSightingsAndPreservesEvents() throws {
        let container = TestModelContainer.create()
        let context = container.mainContext
        let event = TestDataFactory.makeEvent()
        let sighting = TestDataFactory.makeSighting(firstName: "Test", event: event)
        event.sightings = [sighting]
        context.insert(event)
        context.insert(sighting)
        try context.save()

        XCTAssertTrue(SettingsService.deleteAllSightings(context: context))
        XCTAssertTrue(try context.fetch(FetchDescriptor<JerseySighting>()).isEmpty)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Event>()).count, 1)
    }

    func testDeleteAllSightingsSucceedsForEmptyStore() {
        let container = TestModelContainer.create()
        let context = container.mainContext

        XCTAssertTrue(SettingsService.deleteAllSightings(context: context))
    }

    func testResetAllDataRemovesEventsAndSightings() async throws {
        let container = TestModelContainer.create()
        let context = container.mainContext
        let event = TestDataFactory.makeEvent()
        let sighting = TestDataFactory.makeSighting(firstName: "Test", event: event)
        event.sightings = [sighting]
        context.insert(event)
        context.insert(sighting)
        try context.save()

        let resetSucceeded = await SettingsService.resetAllData(context: context)
        XCTAssertTrue(resetSucceeded)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<JerseySighting>()).isEmpty)
    }

    func testResetAllDataSucceedsForEmptyStore() async {
        let container = TestModelContainer.create()
        let context = container.mainContext

        let resetSucceeded = await SettingsService.resetAllData(context: context)
        XCTAssertTrue(resetSucceeded)
    }
}
