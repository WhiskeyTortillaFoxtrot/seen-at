import SwiftUI
import SwiftData
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.seenat", category: "DeepLink")

struct DeepLinkNavigationState {
    var eventToTrack: Event?
    var selectedTab: Int
    var deepLinkEventID: UUID?
    var shouldReportError = false

    mutating func apply(_ resolution: DeepLinkService.Resolution) {
        switch resolution {
        case .openEvent(let event, let selectedTab):
            eventToTrack = event
            self.selectedTab = selectedTab
            deepLinkEventID = nil
            shouldReportError = false
        case .notFound:
            shouldReportError = true
        }
    }
}

struct ContentView: View {
    @Binding var deepLinkEventID: UUID?
    let onDeepLinkError: (() -> Void)?

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
            do {
                var navigationState = DeepLinkNavigationState(
                    eventToTrack: eventToTrack,
                    selectedTab: selectedTab,
                    deepLinkEventID: deepLinkEventID
                )
                navigationState.apply(try DeepLinkService.resolve(eventID: id, context: context))
                eventToTrack = navigationState.eventToTrack
                selectedTab = navigationState.selectedTab
                deepLinkEventID = navigationState.deepLinkEventID
                if navigationState.shouldReportError {
                    onDeepLinkError?()
                }
            } catch {
                logger.error("Failed to fetch deep-linked event: \(error, privacy: .auto)")
                onDeepLinkError?()
            }
        }
    }
}
