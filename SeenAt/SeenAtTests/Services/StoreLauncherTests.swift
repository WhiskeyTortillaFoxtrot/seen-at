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
}
