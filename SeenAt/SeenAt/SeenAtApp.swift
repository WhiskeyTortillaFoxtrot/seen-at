import SwiftUI
import SwiftData
import Observation
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.seenat", category: "Store")

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

    @State private var deepLinkEventID: UUID?
    @State private var deepLinkError: DeepLinkError?
    @State private var splashState = SplashState()
    @State private var storeState = StoreState()

    init() {
        let storeState = StoreState()
        _storeState = State(wrappedValue: storeState)
        let config = ModelConfiguration()

        do {
            container = try ModelContainer(
                for: Team.self, Event.self, JerseySighting.self,
                migrationPlan: SeenAtMigrationPlan.self,
                configurations: config
            )
        } catch {
            logger.error("ModelContainer creation with migration failed: \(error, privacy: .public)")
            do {
                container = try ModelContainer(
                    for: Team.self, Event.self, JerseySighting.self,
                    configurations: config
                )
            } catch {
                logger.error("ModelContainer creation without migration failed: \(error, privacy: .public)")
                storeState.error = error
                storeState.storeURL = config.url
                container = nil
                return
            }
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
}