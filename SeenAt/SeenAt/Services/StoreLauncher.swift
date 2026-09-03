import Foundation
import SwiftData
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.seenat", category: "StoreLauncher")

/// Coarse launch phases reported to the splash screen. Phase boundaries sit between
/// MainActor hops, so reporting never touches background state.
enum LaunchPhase: String, Sendable {
    case preparingBackup
    case openingStore
    case finalizing
    case restoringBackup

    var displayName: String {
        switch self {
        case .preparingBackup: "Backing up your data…"
        case .openingStore: "Opening your library…"
        case .finalizing: "Finishing up…"
        case .restoringBackup: "Restoring your backup…"
        }
    }
}

struct LaunchTimeoutError: LocalizedError, Sendable {
    var errorDescription: String? {
        "Startup took too long and was stopped. Please try again."
    }
}

/// Wraps a non-backup file error that crossed a background boundary, preserving its
/// message for display. Backup errors keep their original identity (see PrepOutcome).
struct LaunchFileError: LocalizedError, Sendable {
    let message: String
    var errorDescription: String? { message }
}

struct StoreLauncher {
    struct Result {
        let container: ModelContainer?
        let storeState: StoreState
    }

    /// Per-phase watchdog for background file work. `ModelContainer` creation itself
    /// stays on the main actor (a SwiftData requirement) and is not guarded by this.
    static let launchTimeoutSeconds: UInt64 = 20

    /// Async entry point. File traversal, copying, validation, and hashing run on
    /// detached background tasks; `ModelContainer` creation and all `StoreState`
    /// mutation stay on the main actor. `onPhase` is always invoked on the main actor.
    @MainActor
    static func launchAsync(
        containerFactory: @MainActor @Sendable (ModelConfiguration) throws -> ModelContainer,
        onPhase: ((LaunchPhase) -> Void)? = nil,
        timeoutSeconds: UInt64 = launchTimeoutSeconds
    ) async -> Result {
        await runLaunch(containerFactory: containerFactory, onPhase: onPhase, timeoutSeconds: timeoutSeconds)
    }

    /// Races `operation` against a sleep. Only used to bound background file work;
    /// callers map `LaunchTimeoutError` to a retryable store-load failure.
    static func withTimeout<T: Sendable>(seconds: UInt64, operation: @Sendable @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask(operation: operation)
            group.addTask {
                try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
                throw LaunchTimeoutError()
            }
            guard let first = try await group.next() else {
                throw LaunchTimeoutError()
            }
            group.cancelAll()
            return first
        }
    }

    // MARK: - Private

    /// Outcome of the background backup-preparation phase. Carries the rollback ID,
    /// the validation failure (if migration proceeds without a backup), or the
    /// already-mapped failure reason plus an error that preserves the original
    /// backup error's identity whenever possible.
    private struct PrepOutcome: Sendable {
        var rollbackID: UUID?
        var validationFailure: BackupValidationFailure?
        var failureReason: StoreFailureReason?
        var failure: PrepFailure?

        var logMessage: String {
            switch failure {
            case .backup(let backupError):
                backupError.localizedDescription
            case .other(let message):
                message
            case nil:
                "Unknown preparation failure"
            }
        }
    }

    private enum PrepFailure: Sendable {
        case backup(StoreBackupService.BackupError)
        case other(message: String)
    }

    @MainActor
    private static func runLaunch(
        containerFactory: @MainActor @Sendable (ModelConfiguration) throws -> ModelContainer,
        onPhase: ((LaunchPhase) -> Void)?,
        timeoutSeconds: UInt64
    ) async -> Result {
        DiagnosticsService.shared.log(category: "Store", level: .info, message: "Store launch started")

        let storeState = StoreState()
        let storeURL = StoreBackupService.defaultStoreURL()
        let applicationSupportURL = StoreBackupService.applicationSupportURL(for: storeURL)
        let config = ModelConfiguration(url: storeURL)

        onPhase?(.preparingBackup)
        let prep: PrepOutcome
        do {
            prep = try await withTimeout(seconds: timeoutSeconds) {
                await Task.detached(priority: .userInitiated) {
                    let fileManager = FileManager()
                    var validationFailure: BackupValidationFailure?
                    do {
                        let id = try StoreBackupService.prepareForMigration(
                            storeURL: storeURL,
                            applicationSupportURL: applicationSupportURL,
                            targetSchemaVersion: SeenAtMigrationPlan.currentVersion,
                            fileManager: fileManager,
                            onBackupValidationFailure: { validationFailure = $0 }
                        )
                        return PrepOutcome(rollbackID: id, validationFailure: validationFailure, failureReason: nil, failure: nil)
                    } catch let backupError as StoreBackupService.BackupError {
                        return PrepOutcome(rollbackID: nil, validationFailure: nil, failureReason: mapPrepError(backupError), failure: .backup(backupError))
                    } catch {
                        return PrepOutcome(rollbackID: nil, validationFailure: nil, failureReason: .storeLoad, failure: .other(message: error.localizedDescription))
                    }
                }.value
            }
        } catch {
            return timeoutResult(storeURL: storeURL, underlying: error)
        }

        if let reason = prep.failureReason {
            logger.error("Store backup preparation failed: \(prep.logMessage, privacy: .public)")
            DiagnosticsService.shared.log(category: "Store", level: .error, message: "Store backup preparation failed: \(prep.logMessage)")
            switch prep.failure {
            case .backup(let backupError):
                storeState.error = backupError
            case .other(let message):
                storeState.error = LaunchFileError(message: message)
            case nil:
                break
            }
            storeState.storeURL = storeURL
            storeState.failureReason = reason
            return Result(container: nil, storeState: storeState)
        }

        let rollbackID = prep.rollbackID
        if let rollbackID {
            DiagnosticsService.shared.log(category: "Store", level: .info, message: "Migration backup prepared with rollbackID: \(rollbackID.uuidString.prefix(8))...")
        } else if let backupValidationFailure = prep.validationFailure {
            DiagnosticsService.shared.log(category: "Store", level: .warning, message: "Migration backup could not be created and was skipped: \(backupValidationFailure.message)")
        } else {
            DiagnosticsService.shared.log(category: "Store", level: .info, message: "No migration backup needed")
        }

        onPhase?(.openingStore)
        var container: ModelContainer?
        do {
            let loadedContainer = try containerFactory(config)
            DiagnosticsService.shared.log(category: "Store", level: .info, message: "ModelContainer created successfully")
            onPhase?(.finalizing)
            do {
                try await withTimeout(seconds: timeoutSeconds) {
                    try await Task.detached(priority: .userInitiated) {
                        try StoreBackupService.completeMigrationAttempt(applicationSupportURL: applicationSupportURL)
                    }.value
                }
                DiagnosticsService.shared.log(category: "Store", level: .info, message: "Migration attempt finalized")
            } catch {
                if error is LaunchTimeoutError {
                    return timeoutResult(storeURL: storeURL, underlying: error)
                }
                logger.error("Migration attempt could not be finalized: \(error, privacy: .public)")
                DiagnosticsService.shared.log(category: "Store", level: .error, message: "Migration finalization failed: \(error.localizedDescription)")
                storeState.error = error
                storeState.storeURL = storeURL
                storeState.failureReason = .migrationFinalization
                return Result(container: nil, storeState: storeState)
            }
            do {
                try await withTimeout(seconds: timeoutSeconds) {
                    try await Task.detached(priority: .userInitiated) {
                        try StoreBackupService.cleanupAfterSuccessfulLaunch(applicationSupportURL: applicationSupportURL)
                    }.value
                }
            } catch {
                logger.error("Post-launch migration cleanup failed: \(error, privacy: .public)")
                DiagnosticsService.shared.log(category: "Store", level: .warning, message: "Post-launch cleanup failed: \(error.localizedDescription)")
            }
            container = loadedContainer
        } catch {
            let migrationError = error
            logger.error("ModelContainer creation or migration failed: \(migrationError, privacy: .public)")
            DiagnosticsService.shared.log(category: "Store", level: .error, message: "ModelContainer creation failed: \(migrationError.localizedDescription)")
            guard let rollbackID else {
                storeState.error = migrationError
                storeState.storeURL = storeURL
                storeState.failureReason = .storeLoad
                return Result(container: nil, storeState: storeState)
            }

            onPhase?(.restoringBackup)
            var recoveryError: Error?
            do {
                try await withTimeout(seconds: timeoutSeconds) {
                    try await Task.detached(priority: .userInitiated) {
                        try StoreBackupService.restoreCurrentBackup(
                            storeURL: storeURL,
                            applicationSupportURL: applicationSupportURL,
                            expectedSchemaVersion: SeenAtMigrationPlan.currentVersion,
                            backupID: rollbackID,
                            fileManager: FileManager()
                        )
                    }.value
                }

                let recoveredContainer = try containerFactory(config)
                onPhase?(.finalizing)
                do {
                    try await withTimeout(seconds: timeoutSeconds) {
                        try await Task.detached(priority: .userInitiated) {
                            try StoreBackupService.completeMigrationAttempt(applicationSupportURL: applicationSupportURL)
                        }.value
                    }
                } catch {
                    if error is LaunchTimeoutError {
                        return timeoutResult(storeURL: storeURL, underlying: error)
                    }
                    recoveryError = error
                    logger.error("Restored migration attempt could not be finalized: \(error, privacy: .public)")
                    DiagnosticsService.shared.log(category: "Store", level: .error, message: "Restored migration finalization failed: \(error.localizedDescription)")
                    storeState.error = error
                    storeState.storeURL = storeURL
                    storeState.failureReason = .restoredMigrationFinalization
                    return Result(container: nil, storeState: storeState)
                }
                do {
                    try await withTimeout(seconds: timeoutSeconds) {
                        try await Task.detached(priority: .userInitiated) {
                            try StoreBackupService.cleanupAfterSuccessfulLaunch(applicationSupportURL: applicationSupportURL)
                        }.value
                    }
                } catch {
                    logger.error("Post-restore migration cleanup failed: \(error, privacy: .public)")
                    DiagnosticsService.shared.log(category: "Store", level: .warning, message: "Post-restore cleanup failed: \(error.localizedDescription)")
                }
                container = recoveredContainer
                logger.info("Restored and reopened the migration backup after store failure")
                DiagnosticsService.shared.log(category: "Store", level: .info, message: "Store recovered from migration backup")
            } catch {
                if error is LaunchTimeoutError {
                    return timeoutResult(storeURL: storeURL, underlying: error)
                }
                recoveryError = error
                logger.error("Could not restore the migration backup: \(error, privacy: .public)")
                DiagnosticsService.shared.log(category: "Store", level: .error, message: "Backup restoration failed: \(error.localizedDescription)")
                await Task.detached(priority: .userInitiated) {
                    try? StoreBackupService.completeMigrationAttempt(applicationSupportURL: applicationSupportURL)
                }.value
            }
            storeState.error = recoveryError ?? migrationError
            storeState.storeURL = storeURL
            storeState.failureReason = .restoreFailed
        }

        return Result(container: container, storeState: storeState)
    }

    private static func mapPrepError(_ error: StoreBackupService.BackupError) -> StoreFailureReason {
        switch error {
        case .migrationFinalization:
            .migrationFinalization
        case .recoveryRequired:
            // Recovery quarantined live data but could not safely reopen it.
            .corruptedRecovery
        case .staleMigrationAttempt:
            // An interrupted attempt points at state that may no longer match this store.
            .corruptedRecovery
        case .invalidBackup:
            // The backup itself is invalid, but the live store remains available to reset.
            .recoveryRequired
        default:
            .storeLoad
        }
    }

    @MainActor
    private static func timeoutResult(storeURL: URL, underlying: Error) -> Result {
        logger.error("Store launch timed out: \(underlying.localizedDescription, privacy: .public)")
        DiagnosticsService.shared.log(category: "Store", level: .error, message: "Store launch timed out: \(underlying.localizedDescription)")
        let storeState = StoreState()
        storeState.error = underlying
        storeState.storeURL = storeURL
        storeState.failureReason = .storeLoad
        return Result(container: nil, storeState: storeState)
    }

    @MainActor
    static func seedIfNeeded(in container: ModelContainer) async {
        await TeamSeedService.seedIfNeeded(modelContext: container.mainContext)
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--seedData") {
            if await SeedData.seedIfNeeded(in: container.mainContext) {
                DiagnosticsService.shared.log(category: "Store", level: .info, message: "Seed data inserted")
            }
        }
        #endif
        DiagnosticsService.shared.log(category: "Store", level: .info, message: "Team seeding completed")
    }

    @MainActor
    static func startLiveActivities(for container: ModelContainer) async {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: .now)
        guard let startOfTomorrow = cal.date(byAdding: .day, value: 1, to: startOfToday) else {
            DiagnosticsService.shared.log(category: "Store", level: .error, message: "Could not calculate tomorrow for Live Activity startup")
            return
        }
        let todayPredicate = #Predicate<Event> {
            $0.date >= startOfToday && $0.date < startOfTomorrow
        }
        let context = container.mainContext
        let todayEvents = (try? context.fetch(FetchDescriptor(predicate: todayPredicate))) ?? []
        DiagnosticsService.shared.log(category: "Store", level: .info, message: "Found \(todayEvents.count) today events for Live Activity startup")
        await LiveActivityManager.endStaleActivities(for: todayEvents)
        if let event = LiveActivityManager.findBestTodayEvent(in: todayEvents) {
            let names = [event.homeTeam, event.awayTeam].compactMap { $0 }
            let teamPredicate = #Predicate<Team> { names.contains($0.name) }
            let teams = (try? context.fetch(FetchDescriptor(predicate: teamPredicate))) ?? []
            await LiveActivityManager.startOrUpdate(for: event, teams: teams)
            DiagnosticsService.shared.log(category: "Store", level: .info, message: "Live Activity started for event: \(event.title)")
        } else {
            DiagnosticsService.shared.log(category: "Store", level: .info, message: "No today events found for Live Activity")
        }
    }
}
