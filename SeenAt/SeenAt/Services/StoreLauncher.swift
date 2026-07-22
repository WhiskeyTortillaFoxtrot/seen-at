import Foundation
import SwiftData
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.seenat", category: "StoreLauncher")

struct StoreLauncher {
    struct Result {
        let container: ModelContainer?
        let storeState: StoreState
    }

    @MainActor
    static func launch(
        containerFactory: (ModelConfiguration) throws -> ModelContainer
    ) -> Result {
        let storeState = StoreState()
        let storeURL = StoreBackupService.defaultStoreURL()
        let applicationSupportURL = StoreBackupService.applicationSupportURL(for: storeURL)
        let config = ModelConfiguration(url: storeURL)

        let rollbackID: UUID?
        do {
            rollbackID = try StoreBackupService.prepareForMigration(
                storeURL: storeURL,
                applicationSupportURL: applicationSupportURL,
                targetSchemaVersion: SeenAtMigrationPlan.currentVersion
            )
        } catch {
            logger.error("Store backup preparation failed: \(error, privacy: .public)")
            storeState.error = error
            storeState.storeURL = storeURL
            switch error {
            case StoreBackupService.BackupError.migrationFinalization:
                storeState.failureReason = .migrationFinalization
            case StoreBackupService.BackupError.recoveryRequired:
                storeState.failureReason = .recoveryRequired
            case StoreBackupService.BackupError.staleMigrationAttempt:
                storeState.failureReason = .recoveryRequired
            case StoreBackupService.BackupError.invalidBackup:
                storeState.failureReason = .recoveryRequired
            default:
                storeState.failureReason = .storeLoad
            }
            return Result(container: nil, storeState: storeState)
        }

        var container: ModelContainer?
        do {
            let loadedContainer = try containerFactory(config)
            do {
                try StoreBackupService.completeMigrationAttempt(
                    applicationSupportURL: applicationSupportURL
                )
            } catch {
                logger.error("Migration attempt could not be finalized: \(error, privacy: .public)")
                storeState.error = error
                storeState.storeURL = storeURL
                storeState.failureReason = .migrationFinalization
                return Result(container: nil, storeState: storeState)
            }
            do {
                try StoreBackupService.cleanupAfterSuccessfulLaunch(
                    applicationSupportURL: applicationSupportURL
                )
            } catch {
                logger.error("Post-launch migration cleanup failed: \(error, privacy: .public)")
            }
            container = loadedContainer
        } catch {
            let migrationError = error
            logger.error("ModelContainer creation or migration failed: \(migrationError, privacy: .public)")
            guard let rollbackID else {
                storeState.error = migrationError
                storeState.storeURL = storeURL
                storeState.failureReason = .storeLoad
                return Result(container: nil, storeState: storeState)
            }

            var recoveryError: Error?
            do {
                try StoreBackupService.restoreCurrentBackup(
                    storeURL: storeURL,
                    applicationSupportURL: applicationSupportURL,
                    expectedSchemaVersion: SeenAtMigrationPlan.currentVersion,
                    backupID: rollbackID
                )

                do {
                    let recoveredContainer = try containerFactory(config)
                    do {
                        try StoreBackupService.completeMigrationAttempt(
                            applicationSupportURL: applicationSupportURL
                        )
                    } catch {
                        recoveryError = error
                        logger.error("Restored migration attempt could not be finalized: \(error, privacy: .public)")
                        storeState.error = error
                        storeState.storeURL = storeURL
                        storeState.failureReason = .restoredMigrationFinalization
                        return Result(container: nil, storeState: storeState)
                    }
                    do {
                        try StoreBackupService.cleanupAfterSuccessfulLaunch(
                            applicationSupportURL: applicationSupportURL
                        )
                    } catch {
                        logger.error("Post-restore migration cleanup failed: \(error, privacy: .public)")
                    }
                    container = recoveredContainer
                    logger.info("Restored and reopened the migration backup after store failure")
                    storeState.recoveryCompleted = true
                } catch {
                    recoveryError = error
                    logger.error("Restored migration backup could not be reopened: \(error, privacy: .public)")
                    try? StoreBackupService.completeMigrationAttempt(
                        applicationSupportURL: applicationSupportURL
                    )
                    storeState.failureReason = .restoreFailed
                    storeState.recoveryCompleted = true
                }
            } catch {
                recoveryError = error
                logger.error("Could not restore the migration backup: \(error, privacy: .public)")
                try? StoreBackupService.completeMigrationAttempt(
                    applicationSupportURL: applicationSupportURL
                )
            }
            storeState.error = recoveryError ?? migrationError
            storeState.storeURL = storeURL
            storeState.failureReason = .restoreFailed
        }

        return Result(container: container, storeState: storeState)
    }
}
