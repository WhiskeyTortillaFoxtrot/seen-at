import SwiftUI
import SwiftData

struct ContentView: View {
    @Binding var deepLinkEventID: UUID?

    @Environment(\.modelContext) private var context
    @AppStorage("defaultSport") private var defaultSport: String = "mlb"
    @State private var selectedTab = 0
    @State private var eventToTrack: Event?

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(eventToTrack: $eventToTrack)
            }
            .tabItem {
                Label("Games", systemImage: Team.sportIcon(for: defaultSport))
            }
            .tag(0)

            NavigationStack {
                StatsView()
            }
            .tabItem {
                Label("Stats", systemImage: "chart.bar")
            }
            .tag(1)

            NavigationStack {
                SearchView()
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }
            .tag(2)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
            .tag(3)
        }
        .task(id: deepLinkEventID) {
            guard let id = deepLinkEventID else { return }
            let predicate = #Predicate<Event> { $0.id == id }
            let descriptor = FetchDescriptor(predicate: predicate)
            if let event = try? context.fetch(descriptor).first {
                eventToTrack = event
                selectedTab = 0
            }
            deepLinkEventID = nil
        }
    }
}
