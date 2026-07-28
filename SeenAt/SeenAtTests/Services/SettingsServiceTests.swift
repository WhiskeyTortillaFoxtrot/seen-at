import XCTest
@testable import SeenAt
import SwiftData

@MainActor
final class SettingsServiceTests: XCTestCase {
    private enum TestError: Error {
        case fetchFailed
    }

    private final class MockSettingsServiceDependencies: SettingsServiceDependencies {
        var fetchSightingsError: Error?
        var fetchEventsError: Error?
        var saveResult = true
        var saveCallCount = 0
        var rollbackCallCount = 0
        var endAllActivitiesCallCount = 0
        var clearPhotoCacheCallCount = 0

        func fetchSightings(from context: ModelContext) throws -> [JerseySighting] {
            if let fetchSightingsError {
                throw fetchSightingsError
            }
            return try context.fetch(FetchDescriptor<JerseySighting>())
        }

        func fetchEvents(from context: ModelContext) throws -> [Event] {
            if let fetchEventsError {
                throw fetchEventsError
            }
            return try context.fetch(FetchDescriptor<Event>())
        }

        func save(context: ModelContext, message: String) -> Bool {
            saveCallCount += 1
            return saveResult
        }

        func rollback(context: ModelContext) {
            rollbackCallCount += 1
            context.rollback()
        }

        func endAllActivities() async {
            endAllActivitiesCallCount += 1
        }

        func clearPhotoCache() {
            clearPhotoCacheCallCount += 1
        }
    }

    func testDeleteAllSightingsRemovesSightingsAndPreservesEvents() throws {
        let container = TestModelContainer.create()
        let context = container.mainContext
        let event = TestDataFactory.makeEvent()
        let sighting = TestDataFactory.makeSighting(firstName: "Test", event: event)
        let orphanSighting = TestDataFactory.makeSighting(firstName: "Orphan")
        event.sightings = [sighting]
        context.insert(event)
        context.insert(sighting)
        context.insert(orphanSighting)
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

    func testDeleteAllSightingsReturnsFalseWhenFetchingSightingsFails() {
        let container = TestModelContainer.create()
        let dependencies = MockSettingsServiceDependencies()
        dependencies.fetchSightingsError = TestError.fetchFailed

        let deleteSucceeded = SettingsService.deleteAllSightings(
            context: container.mainContext,
            dependencies: dependencies
        )

        XCTAssertFalse(deleteSucceeded)
        XCTAssertEqual(dependencies.saveCallCount, 0)
    }

    func testDeleteAllSightingsReturnsFalseWhenSaveFails() throws {
        let container = TestModelContainer.create()
        let context = container.mainContext
        let dependencies = MockSettingsServiceDependencies()
        dependencies.saveResult = false
        let event = TestDataFactory.makeEvent()
        let sighting = TestDataFactory.makeSighting(firstName: "Test", event: event)
        event.sightings = [sighting]
        context.insert(event)
        context.insert(sighting)
        try context.save()

        let deleteSucceeded = SettingsService.deleteAllSightings(
            context: context,
            dependencies: dependencies
        )

        XCTAssertFalse(deleteSucceeded)
        XCTAssertEqual(dependencies.saveCallCount, 1)
        XCTAssertEqual(dependencies.rollbackCallCount, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<JerseySighting>()).count, 1)
    }

    func testResetAllDataRemovesEventsAndSightings() async throws {
        let container = TestModelContainer.create()
        let context = container.mainContext
        let dependencies = MockSettingsServiceDependencies()
        let event = TestDataFactory.makeEvent()
        let sighting = TestDataFactory.makeSighting(firstName: "Test", event: event)
        let orphanSighting = TestDataFactory.makeSighting(firstName: "Orphan")
        event.sightings = [sighting]
        context.insert(event)
        context.insert(sighting)
        context.insert(orphanSighting)
        try context.save()

        let resetSucceeded = await SettingsService.resetAllData(
            context: context,
            dependencies: dependencies
        )
        XCTAssertTrue(resetSucceeded)
        XCTAssertEqual(dependencies.endAllActivitiesCallCount, 1)
        XCTAssertEqual(dependencies.clearPhotoCacheCallCount, 1)
        XCTAssertEqual(dependencies.saveCallCount, 1)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Event>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<JerseySighting>()).isEmpty)
    }

    func testResetAllDataReturnsFalseWhenFetchingEventsFailsWithoutSideEffects() async {
        let container = TestModelContainer.create()
        let dependencies = MockSettingsServiceDependencies()
        dependencies.fetchEventsError = TestError.fetchFailed

        let resetSucceeded = await SettingsService.resetAllData(
            context: container.mainContext,
            dependencies: dependencies
        )

        XCTAssertFalse(resetSucceeded)
        XCTAssertEqual(dependencies.endAllActivitiesCallCount, 0)
        XCTAssertEqual(dependencies.clearPhotoCacheCallCount, 0)
        XCTAssertEqual(dependencies.rollbackCallCount, 0)
    }

    func testResetAllDataReturnsFalseWhenSaveFailsAndRollsBack() async throws {
        let container = TestModelContainer.create()
        let context = container.mainContext
        let dependencies = MockSettingsServiceDependencies()
        dependencies.saveResult = false
        context.insert(TestDataFactory.makeEvent())
        try context.save()

        let resetSucceeded = await SettingsService.resetAllData(
            context: context,
            dependencies: dependencies
        )

        XCTAssertFalse(resetSucceeded)
        XCTAssertEqual(dependencies.endAllActivitiesCallCount, 0)
        XCTAssertEqual(dependencies.clearPhotoCacheCallCount, 0)
        XCTAssertEqual(dependencies.saveCallCount, 1)
        XCTAssertEqual(dependencies.rollbackCallCount, 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Event>()).count, 1)
    }

    func testResetAllDataSucceedsForEmptyStore() async {
        let container = TestModelContainer.create()
        let context = container.mainContext

        let resetSucceeded = await SettingsService.resetAllData(context: context)
        XCTAssertTrue(resetSucceeded)
    }
}
