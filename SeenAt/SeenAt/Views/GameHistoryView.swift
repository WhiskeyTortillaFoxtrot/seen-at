import SwiftUI
import SwiftData

struct GameHistoryView: View {
    @Query(sort: \Event.date, order: .reverse) private var events: [Event]

    private var pastEvents: [Event] {
        EventDateSections(events: events, now: .now, calendar: .current).past
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { _ in
            List {
                if pastEvents.isEmpty {
                    ContentUnavailableView(
                        "No Past Games",
                        systemImage: "calendar",
                        description: Text("Completed games will appear here.")
                    )
                } else {
                    ForEach(pastEvents) { event in
                        NavigationLink(value: event) {
                            EventRow(event: event)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .listRowBackground(Color.clear)
        }
        .navigationTitle("Game History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .background { StadiumBackdrop(usesDailyImage: true) }
        .navigationDestination(for: Event.self) { event in
            EventSummaryView(event: event)
        }
    }
}
