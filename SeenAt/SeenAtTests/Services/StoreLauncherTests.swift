import XCTest
@testable import SeenAt
import SwiftData

@MainActor
final class StoreLauncherTests: XCTestCase {
    func testLaunchReturnsContainerOnSuccess() async {
        let result = await StoreLauncher.launchAsync { config in
            try ModelContainer(
                for: Team.self, Event.self, JerseySighting.self,
                configurations: config
            )
        }
        XCTAssertNotNil(result.container)
        XCTAssertNil(result.storeState.error)
        XCTAssertEqual(result.storeState.failureReason, .storeLoad)
    }

    func testLaunchReturnsNilContainerOnFactoryFailure() async {
        struct LaunchError: Error, LocalizedError {
            var errorDescription: String? { "test error" }
        }

        let result = await StoreLauncher.launchAsync { _ in
            throw LaunchError()
        }
        XCTAssertNil(result.container)
        XCTAssertNotNil(result.storeState.error)
    }

    func testLaunchSetsStoreURL() async {
        struct LaunchError: Error, LocalizedError {
            var errorDescription: String? { "test error" }
        }

        let result = await StoreLauncher.launchAsync { _ in
            throw LaunchError()
        }
        XCTAssertNotNil(result.storeState.storeURL)
    }

    func testLaunchAsyncReportsCoarsePhasesInOrder() async {
        var phases: [LaunchPhase] = []
        let result = await StoreLauncher.launchAsync(
            containerFactory: { config in
                try ModelContainer(
                    for: Team.self, Event.self, JerseySighting.self,
                    configurations: config
                )
            },
            onPhase: { phases.append($0) }
        )
        XCTAssertNotNil(result.container)
        XCTAssertEqual(phases, [.preparingBackup, .openingStore, .finalizing])
    }

    func testWithTimeoutReturnsFastOperation() async throws {
        let value = try await StoreLauncher.withTimeout(seconds: 5) { "done" }
        XCTAssertEqual(value, "done")
    }

    func testWithTimeoutThrowsTimeoutOnSlowOperation() async {
        do {
            _ = try await StoreLauncher.withTimeout(seconds: 0) {
                try await Task.sleep(nanoseconds: 500_000_000)
                return "too slow"
            }
            XCTFail("Expected LaunchTimeoutError")
        } catch {
            XCTAssertTrue(error is LaunchTimeoutError, "Expected LaunchTimeoutError, got \(error)")
        }
    }

    func testWithTimeoutReturnsBeforeDetachedNonCooperativeOperationFinishes() async {
        let start = Date()
        do {
            _ = try await StoreLauncher.withTimeout(seconds: 0) {
                await Task.detached {
                    Self.nonCooperativeDelay()
                }.value
            }
            XCTFail("Expected LaunchTimeoutError")
        } catch {
            XCTAssertTrue(error is LaunchTimeoutError)
        }
        XCTAssertLessThan(
            Date().timeIntervalSince(start),
            0.25,
            "The watchdog must not wait for detached non-cooperative work to finish"
        )
    }

    func testLaunchTimeoutErrorHasHumanMessage() {
        let message = LaunchTimeoutError().errorDescription
        XCTAssertNotNil(message)
        XCTAssertTrue(message?.contains("try again") == true)
    }

    private nonisolated static func nonCooperativeDelay() -> String {
        Thread.sleep(forTimeInterval: 0.5)
        return "late"
    }

    func testStoreErrorAllowsResetAfterRestoreFailure() {
        let state = StoreState()
        state.failureReason = .restoreFailed
        let view = StoreErrorView(state: state)

        XCTAssertTrue(view.allowsReset)
        XCTAssertEqual(view.message, "Your data could not be loaded. It has been preserved on your device.")
    }

    func testStoreErrorProtectsMigrationFinalizationFromReset() {
        let state = StoreState()
        let view = StoreErrorView(state: state)

        for failureReason in [
            StoreFailureReason.migrationFinalization,
            .restoredMigrationFinalization
        ] {
            state.failureReason = failureReason
            XCTAssertFalse(view.allowsReset)
        }
    }

    func testSeedIfNeededInsertsTeams() async throws {
        UserDefaults.standard.removeObject(forKey: AppPreferences.seedVersionKey)

        let container = TestModelContainer.create()
        defer {
            TestModelContainer.cleanupSQLite(container)
            UserDefaults.standard.removeObject(forKey: AppPreferences.seedVersionKey)
        }

        let beforeCount = (try? container.mainContext.fetch(FetchDescriptor<Team>()))?.count ?? 0

        await StoreLauncher.seedIfNeeded(in: container)

        let afterCount = (try? container.mainContext.fetch(FetchDescriptor<Team>()))?.count ?? 0
        XCTAssertGreaterThan(afterCount, beforeCount)
    }

    func testSeedIfNeededIsIdempotent() async throws {
        UserDefaults.standard.removeObject(forKey: AppPreferences.seedVersionKey)

        let container = TestModelContainer.create()
        defer {
            TestModelContainer.cleanupSQLite(container)
            UserDefaults.standard.removeObject(forKey: AppPreferences.seedVersionKey)
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
