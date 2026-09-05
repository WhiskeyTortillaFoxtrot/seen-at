import SwiftUI
import SwiftData
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.seenat", category: "DeepLink")

struct DeepLinkNavigationState {
    var eventToTrack: Event?
    var eventToSummarize: Event?
    var selectedTab: Int
    var deepLinkDestination: DeepLinkDestination?
    var shouldReportError = false

    mutating func apply(_ resolution: DeepLinkService.Resolution, as destination: DeepLinkDestination) {
        switch resolution {
        case .openEvent(let event, let selectedTab):
            switch destination {
            case .liveTracking:
                eventToTrack = event
            case .eventSummary:
                eventToSummarize = event
            case .stats:
                break
            }
            self.selectedTab = selectedTab
            deepLinkDestination = nil
            shouldReportError = false
        case .notFound:
            shouldReportError = true
        }
    }

    mutating func openStats() {
        selectedTab = 1
        deepLinkDestination = nil
        shouldReportError = false
    }
}

struct ContentView: View {
    @Binding var deepLinkDestination: DeepLinkDestination?
    let onDeepLinkError: (() -> Void)?

    @Environment(\.modelContext) private var context
    @Query(sort: \Event.date, order: .reverse) private var events: [Event]
    @AppStorage(AppPreferences.defaultSportKey) private var defaultSport: String = "mlb"
    @State private var selectedTab = 0
    @State private var eventToTrack: Event?
    @State private var eventToSummarize: Event?

    var body: some View {
        let widgetEvents = events.map(WidgetEventInput.init)

        TabView(selection: $selectedTab) {
            NavigationStack {
                HomeView(eventToTrack: $eventToTrack, eventToSummarize: $eventToSummarize)
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
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .task(id: deepLinkDestination) {
            guard let destination = deepLinkDestination else { return }
            do {
                var navigationState = DeepLinkNavigationState(
                    eventToTrack: eventToTrack,
                    eventToSummarize: eventToSummarize,
                    selectedTab: selectedTab,
                    deepLinkDestination: deepLinkDestination
                )
                switch destination {
                case .stats:
                    navigationState.openStats()
                case .liveTracking(let id), .eventSummary(let id):
                    navigationState.apply(
                        try DeepLinkService.resolve(eventID: id, context: context),
                        as: destination
                    )
                }
                eventToTrack = navigationState.eventToTrack
                eventToSummarize = navigationState.eventToSummarize
                selectedTab = navigationState.selectedTab
                deepLinkDestination = navigationState.deepLinkDestination
                if navigationState.shouldReportError {
                    onDeepLinkError?()
                }
            } catch {
                logger.error("Failed to fetch deep-linked event: \(error, privacy: .auto)")
                onDeepLinkError?()
            }
        }
        .task(id: widgetEvents) {
            WidgetSnapshotService.publish(events: widgetEvents)
        }
    }
}
