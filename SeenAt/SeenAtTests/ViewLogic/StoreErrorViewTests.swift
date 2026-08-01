import XCTest
@testable import SeenAt

@MainActor
final class StoreErrorViewTests: XCTestCase {
    func testAllowsResetForRecoveryRequired() {
        let state = StoreState()
        state.failureReason = .recoveryRequired
        XCTAssertTrue(StoreErrorView(state: state).allowsReset)
    }

    func testAllowsResetForStoreLoad() {
        let state = StoreState()
        state.failureReason = .storeLoad
        XCTAssertTrue(StoreErrorView(state: state).allowsReset)
    }

    func testAllowsResetForRestoreFailed() {
        let state = StoreState()
        state.failureReason = .restoreFailed
        XCTAssertTrue(StoreErrorView(state: state).allowsReset)
    }

    func testAllowsResetForCorruptedRecovery() {
        let state = StoreState()
        state.failureReason = .corruptedRecovery
        XCTAssertTrue(StoreErrorView(state: state).allowsReset)
    }

    func testRecoveryMessagesDistinguishDataStatus() {
        let recoveryRequiredState = StoreState()
        recoveryRequiredState.failureReason = .recoveryRequired
        let recoveryRequiredMessage = StoreErrorView(state: recoveryRequiredState).message
        XCTAssertTrue(recoveryRequiredMessage.contains("Your data has been preserved"))
        XCTAssertTrue(recoveryRequiredMessage.contains("close and reopen the app to retry"))

        let corruptedState = StoreState()
        corruptedState.failureReason = .corruptedRecovery
        let corruptedMessage = StoreErrorView(state: corruptedState).message
        XCTAssertTrue(corruptedMessage.contains("may still be preserved"))
        XCTAssertFalse(corruptedMessage.contains("close and reopen the app to retry"))
    }

    func testDisallowsResetForMigrationFinalization() {
        let state = StoreState()
        state.failureReason = .migrationFinalization
        XCTAssertFalse(StoreErrorView(state: state).allowsReset)
    }

    func testDisallowsResetForRestoredMigrationFinalization() {
        let state = StoreState()
        state.failureReason = .restoredMigrationFinalization
        XCTAssertFalse(StoreErrorView(state: state).allowsReset)
    }
}
