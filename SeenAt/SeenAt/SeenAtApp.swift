import SwiftUI
import SwiftData
import Observation
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.seenat", category: "Store")

enum StoreFailureReason {
    case storeLoad
    case restoreFailed
    case migrationFinalization
    case restoredMigrationFinalization
    case recoveryRequired
}

private enum DeepLinkError: Identifiable {
    case malformedURL
    case eventNotFound

    var id: Self { self }

    var message: String {
        switch self {
        case .malformedURL: return "The link could not be opened. It may be malformed."
        case .eventNotFound: return "The game for this link could not be found."
        }
    }
}

@MainActor
@main
struct SeenAtApp: App {
    let container: ModelContainer?

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    @State private var deepLinkEventID: UUID?
    @State private var deepLinkError: DeepLinkError?
    @State private var splashState = SplashState()
    @State private var storeState = StoreState()

    /// All backup/restore work runs synchronously on `@MainActor` because
    /// SwiftData's `ModelContainer` must be created on the main actor, and the
    /// backup must exist *before* container creation so the recovery path can
    /// restore it on failure.  If launch time becomes a concern, the escape
    /// hatch is pre-warming the backup on a background thread during a push
    /// notification handler or app extension.
    init() {
        let storeState = StoreState()
        _storeState = State(wrappedValue: storeState)
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
            container = nil
            return
        }

        do {
            let loadedContainer = try ModelContainer(
                for: Team.self, Event.self, JerseySighting.self,
                migrationPlan: SeenAtMigrationPlan.self,
                configurations: config
            )
            do {
                try StoreBackupService.completeMigrationAttempt(
                    applicationSupportURL: applicationSupportURL
                )
            } catch {
                logger.error("Migration attempt could not be finalized: \(error, privacy: .public)")
                storeState.error = error
                storeState.storeURL = storeURL
                storeState.failureReason = .migrationFinalization
                container = nil
                return
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
                container = nil
                return
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
                    let recoveredContainer = try ModelContainer(
                        for: Team.self, Event.self, JerseySighting.self,
                        migrationPlan: SeenAtMigrationPlan.self,
                        configurations: config
                    )
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
                        container = nil
                        return
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
                    splashState.isVisible = false
                    return
                } catch {
                    recoveryError = error
                    logger.error("Restored migration backup could not be reopened: \(error, privacy: .public)")
                    try? StoreBackupService.completeMigrationAttempt(
                        applicationSupportURL: applicationSupportURL
                    )
                    storeState.failureReason = .restoreFailed
                }
            } catch {
                recoveryError = error
                logger.error("Could not restore the migration backup: \(error, privacy: .public)")
            }
            storeState.error = recoveryError ?? migrationError
            storeState.storeURL = storeURL
            storeState.failureReason = .restoreFailed
            container = nil
        }

        guard let c = container else { return }
        let state = splashState
        Task {
            await TeamSeedService.seedIfNeeded(modelContext: c.mainContext)
            if ProcessInfo.processInfo.arguments.contains("--seedData") {
                await SeedData.seedIfNeeded(in: c.mainContext)
            }
            state.isVisible = false

            Task {
                let cal = Calendar.current
                let startOfToday = cal.startOfDay(for: .now)
                let startOfTomorrow = cal.date(byAdding: .day, value: 1, to: startOfToday)!
                let todayPredicate = #Predicate<Event> {
                    $0.date >= startOfToday && $0.date < startOfTomorrow
                }
                let context = c.mainContext
                let todayEvents = try? context.fetch(FetchDescriptor(predicate: todayPredicate))
                await LiveActivityManager.endStaleActivities(for: todayEvents ?? [])
                if let event = LiveActivityManager.findBestTodayEvent(in: todayEvents ?? []) {
                    let names = [event.homeTeam, event.awayTeam].compactMap { $0 }
                    let teamPredicate = #Predicate<Team> { names.contains($0.name) }
                    let teams = try? context.fetch(FetchDescriptor(predicate: teamPredicate))
                    await LiveActivityManager.startOrUpdate(for: event, teams: teams ?? [])
                }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            if let container {
                ZStack {
                    ContentView(deepLinkEventID: $deepLinkEventID, onDeepLinkError: { deepLinkError = .eventNotFound })

                    if splashState.isVisible {
                        SplashView()
                            .transition(.opacity)
                    }

                    if !hasSeenOnboarding, !splashState.isVisible {
                        OnboardingView()
                            .transition(.opacity)
                    }
                }
                .animation(.easeOut(duration: 0.5), value: splashState.isVisible)
                .onOpenURL { url in
                    guard url.scheme?.lowercased() == "seenat",
                          url.host?.lowercased() == "live-tracking",
                          let eventID = UUID(uuidString: url.lastPathComponent)
                    else {
                        deepLinkError = .malformedURL
                        return
                    }
                    deepLinkEventID = eventID
                }
                .alert(item: Binding(
                    get: { splashState.isVisible ? nil : deepLinkError },
                    set: { deepLinkError = $0 }
                )) { error in
                    Alert(
                        title: Text("Couldn’t Open Link"),
                        message: Text(error.message),
                        dismissButton: .default(Text("OK"))
                    )
                }
                .modelContainer(container)
            } else {
                StoreErrorView(state: storeState)
            }
        }
    }
}

@MainActor
@Observable
final class SplashState {
    var isVisible = true
}

@MainActor
@Observable
final class StoreState {
    var error: Error?
    var storeURL: URL?
    var recoveryCompleted = false
    var failureReason: StoreFailureReason = .storeLoad
}
