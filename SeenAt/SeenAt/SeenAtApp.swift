import SwiftUI
import SwiftData

@MainActor
@main
struct SeenAtApp: App {
    let container: ModelContainer

    @State private var deepLinkEventID: UUID?

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
            c = try! ModelContainer(
                for: Team.self, Event.self, JerseySighting.self,
                migrationPlan: SeenAtMigrationPlan.self,
                configurations: ModelConfiguration(url: storeURL)
            )
        }
        container = c
        Task {
            await TeamSeedService.seedIfNeeded(modelContext: c.mainContext)
            if ProcessInfo.processInfo.arguments.contains("--seedData") {
                await SeedData.seedIfNeeded(in: c.mainContext)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView(deepLinkEventID: $deepLinkEventID)
                .onOpenURL { url in
                    guard url.scheme == "seenat",
                          url.host == "live-tracking",
                          let eventID = UUID(uuidString: url.lastPathComponent)
                    else { return }
                    deepLinkEventID = eventID
                }
                .task {
                    try? await Task.sleep(for: .seconds(0.5))
                    let context = container.mainContext
                    let teams = try? context.fetch(FetchDescriptor<Team>())
                    guard let teams, !teams.isEmpty else { return }
                    let events = try? context.fetch(FetchDescriptor<Event>())
                    await LiveActivityManager.endStaleActivities(for: events ?? [])
            if let event = LiveActivityManager.findBestTodayEvent(in: events ?? []) {
                await LiveActivityManager.startOrUpdate(for: event, teams: teams)
            }
                }
        }
        .modelContainer(container)
    }
}
