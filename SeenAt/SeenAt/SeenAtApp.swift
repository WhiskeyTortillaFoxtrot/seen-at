import SwiftUI
import SwiftData
import Observation

@MainActor
@main
struct SeenAtApp: App {
    let container: ModelContainer

    @State private var deepLinkEventID: UUID?
    @State private var splashState = SplashState()

    init() {
        let config = ModelConfiguration()
        let c: ModelContainer
        do {
            c = try ModelContainer(
                for: Team.self, Event.self, JerseySighting.self,
                migrationPlan: SeenAtMigrationPlan.self,
                configurations: config
            )
        } catch {
            let storeURL = config.url
            try? FileManager.default.removeItem(at: storeURL)
            do {
                c = try ModelContainer(
                    for: Team.self, Event.self, JerseySighting.self,
                    migrationPlan: SeenAtMigrationPlan.self,
                    configurations: ModelConfiguration(url: storeURL)
                )
            } catch {
                fatalError("Failed to create ModelContainer after store deletion: \(error)")
            }
        }
        container = c
        let state = splashState
        Task {
            await TeamSeedService.seedIfNeeded(modelContext: c.mainContext)
            if ProcessInfo.processInfo.arguments.contains("--seedData") {
                await SeedData.seedIfNeeded(in: c.mainContext)
            }
            let context = c.mainContext
            let teams = try? context.fetch(FetchDescriptor<Team>())
            guard let teams, !teams.isEmpty else { return }
            let events = try? context.fetch(FetchDescriptor<Event>())
            await LiveActivityManager.endStaleActivities(for: events ?? [])
            if let event = LiveActivityManager.findBestTodayEvent(in: events ?? []) {
                await LiveActivityManager.startOrUpdate(for: event, teams: teams)
            }
            state.isVisible = false
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView(deepLinkEventID: $deepLinkEventID)

                if splashState.isVisible {
                    SplashView()
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.5), value: splashState.isVisible)
            .onOpenURL { url in
                guard url.scheme == "seenat",
                      url.host == "live-tracking",
                      let eventID = UUID(uuidString: url.lastPathComponent)
                else { return }
                deepLinkEventID = eventID
            }
        }
        .modelContainer(container)
    }
}

@MainActor
@Observable
final class SplashState {
    var isVisible = true
}