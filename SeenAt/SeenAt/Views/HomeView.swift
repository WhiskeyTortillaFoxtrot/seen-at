import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Event.date, order: .reverse) private var events: [Event]

    @Binding var eventToTrack: Event?

    @State private var showingNewEvent = false
    @State private var selectedLiveEvent: Event?

    private var startOfToday: Date {
        Calendar.current.startOfDay(for: .now)
    }

    private var startOfTomorrow: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: startOfToday)!
    }

    private var upcomingEvents: [Event] {
        events
            .filter { $0.date >= startOfTomorrow }
            .sorted { $0.date < $1.date }
    }

    private var todayEvents: [Event] {
        events.filter { Calendar.current.isDateInToday($0.date) }
    }

    private var pastEvents: [Event] {
        Array(events.filter { $0.date < startOfToday }.prefix(5))
    }

    var body: some View {
        List {
            Section("Today") {
                if todayEvents.isEmpty {
                    suggestionCard
                } else {
                    ForEach(todayEvents) { event in
                        Button {
                            selectedLiveEvent = event
                        } label: {
                            EventRow(event: event)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: deleteEvents(in: todayEvents))
                }
            }

            if !pastEvents.isEmpty {
                Section("Recent") {
                    ForEach(pastEvents) { event in
                        NavigationLink(value: event) {
                            EventRow(event: event)
                                .padding(.horizontal)
                        }
                        .listRowInsets(EdgeInsets())
                    }
                    .onDelete(perform: deleteEvents(in: pastEvents))
                }
            }

            if !upcomingEvents.isEmpty {
                Section("Upcoming") {
                    ForEach(upcomingEvents) { event in
                        EventRow(event: event)
                            .padding(.horizontal)
                    }
                    .onDelete(perform: deleteEvents(in: upcomingEvents))
                }
            }
        }
        .navigationTitle("SeenAt")
        .navigationDestination(for: Event.self) { event in
            EventSummaryView(event: event)
        }
        .navigationDestination(item: $selectedLiveEvent) { event in
            LiveTrackingView(event: event)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingNewEvent = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewEvent) {
            NavigationStack {
                EventFormView { event in
                    showingNewEvent = false
                    if Calendar.current.isDateInToday(event.date) {
                        selectedLiveEvent = event
                    }
                }
            }
        }
        .onChange(of: eventToTrack) { _, event in
            if let event {
                selectedLiveEvent = event
                eventToTrack = nil
            }
        }
    }

    private var suggestionCard: some View {
        Button {
            showingNewEvent = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Track a New Game")
                        .font(.headline)
                    Text("Start tracking jerseys at today's game")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
        }
        .foregroundStyle(.primary)
    }

    private func deleteEvents(in list: [Event]) -> (IndexSet) -> Void {
        { indexSet in
            for index in indexSet {
                if index < list.count {
                    context.delete(list[index])
                }
            }
        }
    }
}

struct EventRow: View {
    let event: Event

    var leadingColor: Color {
        event.teamBreakdown.first?.team.primaryColor ?? .blue
    }

    private var monthText: String {
        event.date.formatted(.dateTime.month(.abbreviated))
    }

    private var dayText: String {
        event.date.formatted(.dateTime.day())
    }

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(leadingColor)
                .frame(width: 4)
                .clipShape(RoundedRectangle(cornerRadius: 2))

            VStack(spacing: 0) {
                Spacer()
                Text(monthText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(dayText)
                    .font(.title)
                    .fontWeight(.semibold)
                Spacer()
            }
            .frame(minWidth: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)

                if let venue = event.venue {
                    HStack(spacing: 2) {
                        Image(systemName: event.watchLocation == .tv ? "tv" : "mappin")
                            .font(.caption)
                        Text(venue)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }

                HStack {
                    Label("\(event.totalCount)", systemImage: "tshirt")
                        .font(.subheadline)
                        .foregroundStyle(leadingColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(leadingColor.opacity(0.1), in: Capsule())

                    if !event.teamBreakdown.isEmpty {
                        HStack(spacing: -4) {
                            ForEach(event.teamBreakdown.prefix(5), id: \.team.id) { team, _ in
                                Circle()
                                    .fill(team.primaryColor)
                                    .frame(width: 16, height: 16)
                                    .overlay(Circle().stroke(.background, lineWidth: 2))
                            }
                        }
                        if event.teamBreakdown.count > 5 {
                            Text("+\(event.teamBreakdown.count - 5)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.leading, 8)
        }
        .padding(.vertical, 4)
    }
}
