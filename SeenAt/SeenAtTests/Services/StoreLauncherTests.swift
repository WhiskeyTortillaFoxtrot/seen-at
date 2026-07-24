import XCTest
@testable import SeenAt
import SwiftData

@MainActor
final class StoreLauncherTests: XCTestCase {
    func testLaunchReturnsContainerOnSuccess() throws {
        let result = StoreLauncher.launch { config in
            try ModelContainer(
                for: Team.self, Event.self, JerseySighting.self,
                configurations: config
            )
        }
        XCTAssertNotNil(result.container)
        XCTAssertNil(result.storeState.error)
        XCTAssertFalse(result.storeState.recoveryCompleted)
        XCTAssertEqual(result.storeState.failureReason, .storeLoad)
    }

    func testLaunchReturnsNilContainerOnFactoryFailure() throws {
        struct LaunchError: Error, LocalizedError {
            var errorDescription: String? { "test error" }
        }

        let result = StoreLauncher.launch { _ in
            throw LaunchError()
        }
        XCTAssertNil(result.container)
        XCTAssertNotNil(result.storeState.error)
    }

    func testLaunchSetsStoreURL() throws {
        struct LaunchError: Error, LocalizedError {
            var errorDescription: String? { "test error" }
        }

        let result = StoreLauncher.launch { _ in
            throw LaunchError()
        }
        XCTAssertNotNil(result.storeState.storeURL)
    }

    func testSeedIfNeededInsertsTeams() async throws {
        UserDefaults.standard.removeObject(forKey: "seedVersion")

        let container = TestModelContainer.create()
        defer {
            TestModelContainer.cleanupSQLite(container)
            UserDefaults.standard.removeObject(forKey: "seedVersion")
        }

        let beforeCount = (try? container.mainContext.fetch(FetchDescriptor<Team>()))?.count ?? 0

        await StoreLauncher.seedIfNeeded(in: container)

        let afterCount = (try? container.mainContext.fetch(FetchDescriptor<Team>()))?.count ?? 0
        XCTAssertGreaterThan(afterCount, beforeCount)
    }

    func testSeedIfNeededIsIdempotent() async throws {
        UserDefaults.standard.removeObject(forKey: "seedVersion")

        let container = TestModelContainer.create()
        defer {
            TestModelContainer.cleanupSQLite(container)
            UserDefaults.standard.removeObject(forKey: "seedVersion")
        }

        await StoreLauncher.seedIfNeeded(in: container)
        let firstCount = (try? container.mainContext.fetch(FetchDescriptor<Team>()))?.count ?? 0

        await StoreLauncher.seedIfNeeded(in: container)
        let secondCount = (try? container.mainContext.fetch(FetchDescriptor<Team>()))?.count ?? 0

        XCTAssertEqual(firstCount, secondCount)
    }

    func testStartLiveActivitiesWithNoEvents() async throws {
        let container = TestModelContainer.create()
        defer { TestModelContainer.cleanupSQLite(container) }

        await StoreLauncher.startLiveActivities(for: container)
    }

    func testStartLiveActivitiesWithTodayEvent() async throws {
        let container = TestModelContainer.create()
        defer { TestModelContainer.cleanupSQLite(container) }

        let team = TestDataFactory.makeTeam()
        container.mainContext.insert(team)

        let event = TestDataFactory.makeEvent(date: Date())
        container.mainContext.insert(event)

        let sighting = TestDataFactory.makeSighting(team: team, firstName: "Test", number: "10", event: event)
        container.mainContext.insert(sighting)
        try container.mainContext.save()

        await StoreLauncher.startLiveActivities(for: container)
    }
}
