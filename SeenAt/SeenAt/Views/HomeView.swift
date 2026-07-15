import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Event.date, order: .reverse) private var events: [Event]

    @Binding var eventToTrack: Event?

    @State private var showingNewEvent = false
    @State private var selectedLiveEvent: Event?
    @State private var selectedUpcomingEvent: Event?

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
                        }
                    }
                    .onDelete(perform: deleteEvents(in: pastEvents))
                }
            }

            if !upcomingEvents.isEmpty {
                Section("Upcoming") {
                    ForEach(upcomingEvents) { event in
                        Button {
                            selectedUpcomingEvent = event
                        } label: {
                            EventRow(event: event)
                        }
                        .buttonStyle(.plain)
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
        .alert(
            selectedUpcomingEvent?.title ?? "",
            isPresented: .init(
                get: { selectedUpcomingEvent != nil },
                set: { if !$0 { selectedUpcomingEvent = nil } }
            )
        ) {
            Button("OK") { selectedUpcomingEvent = nil }
        } message: {
            if let date = selectedUpcomingEvent?.date {
                Text("This game on \(date.formatted(date: .long, time: .omitted)) is in the future. Be sure to check back on gameday to add your sightings!")
            }
        }
    }

    private var suggestionCard: some View {
        Button {
            showingNewEvent = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.urbanist(.title2))
                    .foregroundStyle(Color.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Track a New Game")
                        .font(.urbanist(.headline))
                    Text("Start tracking jerseys at today's game")
                        .font(.urbanist(.caption))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.urbanist(.caption))
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
            try? context.save()
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

    var awayTeamName: String {
        let components = event.title.components(separatedBy: " @ ")
        return components.first ?? event.title
    }

    var homeTeamName: String {
        let components = event.title.components(separatedBy: " @ ")
        guard components.count > 1 else { return "" }
        return "@ \(components[1])"
    }

    var body: some View {
        let breakdown = event.teamBreakdown
        let leadingColor = breakdown.first?.team.primaryColor ?? .blue

        HStack(spacing: 0) {
            Rectangle()
                .fill(leadingColor)
                .frame(width: 4)
                .clipShape(RoundedRectangle(cornerRadius: 2))

            VStack(spacing: 0) {
                Spacer()
                Text(monthText)
                    .font(.urbanist(.caption))
                    .foregroundStyle(.secondary)
                Text(dayText)
                    .font(.urbanist(.title, weight: .semibold))
                Spacer()
            }
            .frame(minWidth: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(awayTeamName)
                    .font(.urbanist(.headline))
                Text(homeTeamName)
                    .font(.urbanist(.headline))

                if let venue = event.venue {
                    HStack(spacing: 2) {
                        Image(systemName: event.watchLocation == .tv ? "tv" : "mappin")
                            .font(.urbanist(.caption))
                        Text(venue)
                            .font(.urbanist(.caption))
                    }
                    .foregroundStyle(.secondary)
                }

                HStack {
                    Label("\(event.totalCount)", systemImage: "tshirt")
                        .font(.urbanist(.subheadline))
                        .foregroundStyle(leadingColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(leadingColor.opacity(0.1), in: Capsule())

                    if !breakdown.isEmpty {
                        HStack(spacing: -4) {
                            ForEach(breakdown.prefix(5), id: \.team.id) { team, _ in
                                Circle()
                                    .fill(team.primaryColor)
                                    .frame(width: 16, height: 16)
                                    .overlay(Circle().stroke(.background, lineWidth: 2))
                            }
                        }
                        if breakdown.count > 5 {
                            Text("+\(breakdown.count - 5)")
                                .font(.urbanist(.caption2))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.leading, 8)
        }
        .padding(.vertical, 8)
        .padding(.horizontal)
        .frame(minHeight: 72)
    }
}
