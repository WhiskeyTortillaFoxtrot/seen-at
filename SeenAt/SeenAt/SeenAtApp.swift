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