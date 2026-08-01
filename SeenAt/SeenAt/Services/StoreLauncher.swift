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
        DiagnosticsService.shared.log(category: "Store", level: .info, message: "Store launch started")

        let storeState = StoreState()
        let storeURL = StoreBackupService.defaultStoreURL()
        let applicationSupportURL = StoreBackupService.applicationSupportURL(for: storeURL)
        let config = ModelConfiguration(url: storeURL)

        let rollbackID: UUID?
        var backupValidationFailure: BackupValidationFailure?
        do {
            rollbackID = try StoreBackupService.prepareForMigration(
                storeURL: storeURL,
                applicationSupportURL: applicationSupportURL,
                targetSchemaVersion: SeenAtMigrationPlan.currentVersion,
                onBackupValidationFailure: { backupValidationFailure = $0 }
            )
            if let rollbackID {
                DiagnosticsService.shared.log(category: "Store", level: .info, message: "Migration backup prepared with rollbackID: \(rollbackID.uuidString.prefix(8))...")
            } else if let backupValidationFailure {
                DiagnosticsService.shared.log(category: "Store", level: .warning, message: "Migration backup could not be created and was skipped: \(backupValidationFailure.message)")
            } else {
                DiagnosticsService.shared.log(category: "Store", level: .info, message: "No migration backup needed")
            }
        } catch {
            logger.error("Store backup preparation failed: \(error, privacy: .public)")
            DiagnosticsService.shared.log(category: "Store", level: .error, message: "Store backup preparation failed: \(error.localizedDescription)")
            storeState.error = error
            storeState.storeURL = storeURL
            switch error {
            case StoreBackupService.BackupError.migrationFinalization:
                storeState.failureReason = .migrationFinalization
            case StoreBackupService.BackupError.recoveryRequired:
                storeState.failureReason = .corruptedRecovery
            case StoreBackupService.BackupError.staleMigrationAttempt:
                storeState.failureReason = .corruptedRecovery
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
            DiagnosticsService.shared.log(category: "Store", level: .info, message: "ModelContainer created successfully")
            do {
                try StoreBackupService.completeMigrationAttempt(
                    applicationSupportURL: applicationSupportURL
                )
                DiagnosticsService.shared.log(category: "Store", level: .info, message: "Migration attempt finalized")
            } catch {
                logger.error("Migration attempt could not be finalized: \(error, privacy: .public)")
                DiagnosticsService.shared.log(category: "Store", level: .error, message: "Migration finalization failed: \(error.localizedDescription)")
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
                        DiagnosticsService.shared.log(category: "Store", level: .error, message: "Restored migration finalization failed: \(error.localizedDescription)")
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
                        DiagnosticsService.shared.log(category: "Store", level: .warning, message: "Post-restore cleanup failed: \(error.localizedDescription)")
                    }
                    container = recoveredContainer
                    logger.info("Restored and reopened the migration backup after store failure")
                    DiagnosticsService.shared.log(category: "Store", level: .info, message: "Store recovered from migration backup")
                } catch {
                    recoveryError = error
                    logger.error("Restored migration backup could not be reopened: \(error, privacy: .public)")
                    DiagnosticsService.shared.log(category: "Store", level: .error, message: "Restored backup could not be reopened: \(error.localizedDescription)")
                    try? StoreBackupService.completeMigrationAttempt(
                        applicationSupportURL: applicationSupportURL
                    )
                    storeState.failureReason = .restoreFailed
                }
            } catch {
                recoveryError = error
                logger.error("Could not restore the migration backup: \(error, privacy: .public)")
                DiagnosticsService.shared.log(category: "Store", level: .error, message: "Backup restoration failed: \(error.localizedDescription)")
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

    @MainActor
    static func seedIfNeeded(in container: ModelContainer) async {
        await TeamSeedService.seedIfNeeded(modelContext: container.mainContext)
        if ProcessInfo.processInfo.arguments.contains("--seedData") {
            SeedData.seedIfNeeded(in: container.mainContext)
            DiagnosticsService.shared.log(category: "Store", level: .info, message: "Seed data inserted")
        }
        DiagnosticsService.shared.log(category: "Store", level: .info, message: "Team seeding completed")
    }

    @MainActor
    static func startLiveActivities(for container: ModelContainer) async {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: .now)
        let startOfTomorrow = cal.date(byAdding: .day, value: 1, to: startOfToday)!
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
