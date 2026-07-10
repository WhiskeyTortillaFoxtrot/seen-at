import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.modelContext) private var context
    @State private var searchText: String = ""
    @State private var results: [SearchResult] = []
    @State private var hasSearched = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Enter a Player Name or Team Name", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { performSearch() }
                    .submitLabel(.search)

                Button("Search", action: performSearch)
                    .buttonStyle(.borderedProminent)
                    .disabled(searchText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()

            if hasSearched {
                if results.isEmpty {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different search term")
                    )
                } else {
                    List(results) { result in
                        NavigationLink {
                            EventSummaryView(event: result.event)
                        } label: {
                            HStack {
                                VStack(spacing: 2) {
                                    Text(result.event.date, format: .dateTime.month(.abbreviated))
                                        .font(.urbanist(.caption))
                                    Text(result.event.date, format: .dateTime.day())
                                        .font(.urbanist(.title3, weight: .semibold))
                                }
                                .frame(minWidth: 44)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.event.title)
                                        .font(.urbanist(.headline))
                                    Text(result.matchedBy)
                                        .font(.urbanist(.caption))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            } else {
                Spacer()
                ContentUnavailableView(
                    "Search Games",
                    systemImage: "magnifyingglass",
                    description: Text("Find games by player or team name")
                )
                Spacer()
            }
        }
        .navigationTitle("Search")
    }

    private func performSearch() {
        let term = searchText.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return }
        hasSearched = true

        let predicate = #Predicate<Event> { event in
            event.title.localizedStandardContains(term)
        }
        let descriptor = FetchDescriptor<Event>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let matchedEvents = (try? context.fetch(descriptor)) ?? []

        let firstNamePredicate = #Predicate<JerseySighting> { sighting in
            sighting.firstName?.localizedStandardContains(term) == true ||
            sighting.lastName?.localizedStandardContains(term) == true
        }
        let playerDesc = FetchDescriptor<JerseySighting>(predicate: firstNamePredicate)
        let matchedSightings = (try? context.fetch(playerDesc)) ?? []
        let eventsFromPlayers = Set(matchedSightings.compactMap { $0.event })

        let allEvents = Array(Set(matchedEvents).union(eventsFromPlayers))
            .sorted { $0.date > $1.date }

        results = allEvents.map { event in
            let matchedBy: String
            if matchedEvents.contains(where: { $0.id == event.id }) {
                matchedBy = "Team match"
            } else {
                matchedBy = "Player match"
            }
            return SearchResult(event: event, matchedBy: matchedBy)
        }
    }
}

struct SearchResult: Identifiable {
    let id = UUID()
    let event: Event
    let matchedBy: String
}
