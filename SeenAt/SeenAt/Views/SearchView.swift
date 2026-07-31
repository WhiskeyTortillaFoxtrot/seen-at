import SwiftUI
import SwiftData

struct SearchFilters {
    var league: String?
    var watchLocation: WatchLocation?
    var venueQuery = ""
    var dateRangeStart = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    var dateRangeEnd = Date()
    var dateRangeActive = false
    var playerNumber = ""
    var showMoreFilters = false

    var hasActiveFilters: Bool {
        league != nil || watchLocation != nil || !venueQuery.isEmpty || dateRangeActive || !playerNumber.isEmpty
    }
}

struct SearchView: View {
    @Environment(\.modelContext) private var context
    @State private var searchText = ""
    @State private var results: [SearchResult] = []
    @State private var hasSearched = false
    @State private var filters = SearchFilters()

    private let leagues: [(id: String, label: String)] = [
        ("mlb", "MLB"), ("nba", "NBA"), ("nfl", "NFL"),
        ("nhl", "NHL"), ("lovb", "LOVB"), ("mls", "MLS"),
        ("nwsl", "NWSL"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Enter a Player Name or Team Name", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { performSearch() }
                    .submitLabel(.search)

                Button("Search", action: performSearch)
                    .buttonStyle(.borderedProminent)
                    .disabled(searchText.trimmingCharacters(in: .whitespaces).isEmpty && !filters.hasActiveFilters)
            }
            .padding()

            VStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        leagueChip("All", icon: nil, id: nil)
                        ForEach(leagues, id: \.id) { league in
                            leagueChip(league.label, icon: Team.sportIcon(for: league.id), id: league.id)
                        }
                    }
                    .padding(.horizontal, 4)
                }

                HStack(spacing: 8) {
                    locationChip("All", location: nil)
                    locationChip("Stadium", location: .stadium)
                    locationChip("TV", location: .tv)
                    Spacer()
                }

                Button {
                    withAnimation { filters.showMoreFilters.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Text(filters.showMoreFilters ? "Less Filters" : "More Filters")
                            .font(.urbanist(.caption))
                        Image(systemName: filters.showMoreFilters ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                }

                if filters.showMoreFilters {
                    VStack(spacing: 8) {
                        TextField("Venue", text: $filters.venueQuery)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { performSearch() }

                        HStack {
                            Toggle("Date Range", isOn: $filters.dateRangeActive)
                                .font(.urbanist(.caption))
                                .onChange(of: filters.dateRangeActive) { performSearch() }
                            if filters.dateRangeActive {
                                Spacer()
                                Button("Clear") {
                                    filters.dateRangeActive = false
                                    performSearch()
                                }
                                .font(.urbanist(.caption))
                                .foregroundStyle(.blue)
                            }
                        }

                        if filters.dateRangeActive {
                            HStack {
                                DatePicker("From", selection: $filters.dateRangeStart, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .onChange(of: filters.dateRangeStart) { performSearch() }
                                DatePicker("To", selection: $filters.dateRangeEnd, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .onChange(of: filters.dateRangeEnd) { performSearch() }
                            }
                        }

                        TextField("Player Number", text: $filters.playerNumber)
                            .textFieldStyle(.roundedBorder)
                            .keyboardType(.numberPad)
                            .onSubmit { performSearch() }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 4)

            if hasSearched {
                if !results.isEmpty {
                    Text("\(results.count) result\(results.count == 1 ? "" : "s")")
                        .font(.urbanist(.caption))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                }

                if results.isEmpty {
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: resultsDescription
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

    private var resultsDescription: Text {
        if filters.hasActiveFilters {
            Text("No games match your search and filter criteria")
        } else {
            Text("Try a different search term")
        }
    }

    private func leagueChip(_ label: String, icon: String?, id: String?) -> some View {
        Button {
            filters.league = id
            performSearch()
        } label: {
            if let icon {
                Label(label, systemImage: icon)
                    .font(.urbanist(.caption, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            } else {
                Text(label)
                    .font(.urbanist(.caption, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
        }
        .buttonStyle(.bordered)
        .tint(filters.league == id ? Color.blue : .gray)
    }

    private func locationChip(_ label: String, location: WatchLocation?) -> some View {
        Button {
            filters.watchLocation = location
            performSearch()
        } label: {
            Text(label)
                .font(.urbanist(.caption, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .tint(filters.watchLocation == location ? Color.blue : .gray)
    }

    private func performSearch() {
        let term = searchText.trimmingCharacters(in: .whitespaces)
        let numberTerm = filters.playerNumber.trimmingCharacters(in: .whitespaces)

        guard !term.isEmpty || !numberTerm.isEmpty || filters.hasActiveFilters else {
            hasSearched = false
            results = []
            return
        }

        hasSearched = true
        var candidateIDs = Set<UUID>()

        if !term.isEmpty {
            let titlePredicate = #Predicate<Event> { event in
                event.title.localizedStandardContains(term)
            }
            let titleDescriptor = FetchDescriptor<Event>(
                predicate: titlePredicate,
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            if let matched = try? context.fetch(titleDescriptor) {
                candidateIDs.formUnion(matched.map { $0.id })
            }

            let namePredicate = #Predicate<JerseySighting> { sighting in
                sighting.firstName?.localizedStandardContains(term) == true ||
                sighting.lastName?.localizedStandardContains(term) == true
            }
            let nameDescriptor = FetchDescriptor<JerseySighting>(predicate: namePredicate)
            if let matched = try? context.fetch(nameDescriptor) {
                candidateIDs.formUnion(matched.compactMap { $0.event?.id })
            }
        }

        if !numberTerm.isEmpty {
            let numberPredicate = #Predicate<JerseySighting> { sighting in
                sighting.playerNumber?.localizedStandardContains(numberTerm) == true
            }
            let numberDescriptor = FetchDescriptor<JerseySighting>(predicate: numberPredicate)
            if let matched = try? context.fetch(numberDescriptor) {
                candidateIDs.formUnion(matched.compactMap { $0.event?.id })
            }
        }

        var eventsToFilter: [Event]
        if !candidateIDs.isEmpty {
            let idList = Array(candidateIDs)
            let idPredicate = #Predicate<Event> { idList.contains($0.id) }
            let descriptor = FetchDescriptor<Event>(
                predicate: idPredicate,
                sortBy: [SortDescriptor(\.date, order: .reverse)]
            )
            eventsToFilter = (try? context.fetch(descriptor)) ?? []
        } else {
            let allDescriptor = FetchDescriptor<Event>(sortBy: [SortDescriptor(\.date, order: .reverse)])
            eventsToFilter = (try? context.fetch(allDescriptor)) ?? []
        }

        if filters.hasActiveFilters {
            if let league = filters.league {
                let teamNames = Set(
                    (try? context.fetch(
                        FetchDescriptor<Team>(predicate: #Predicate { $0.sport == league })
                    ))?.map { $0.name } ?? []
                )
                eventsToFilter = eventsToFilter.filter {
                    guard let away = $0.awayTeam, let home = $0.homeTeam else { return false }
                    return teamNames.contains(away) || teamNames.contains(home)
                }
            }

            if let watchLocation = filters.watchLocation {
                eventsToFilter = eventsToFilter.filter { $0.watchLocation == watchLocation }
            }

            let venueTerm = filters.venueQuery.trimmingCharacters(in: .whitespaces).lowercased()
            if !venueTerm.isEmpty {
                eventsToFilter = eventsToFilter.filter { $0.venue?.lowercased().contains(venueTerm) == true }
            }

            if filters.dateRangeActive {
                eventsToFilter = eventsToFilter.filter {
                    $0.date >= filters.dateRangeStart && $0.date <= filters.dateRangeEnd
                }
            }
        }

        results = eventsToFilter.map { event in
            let matchedBy: String
            if candidateIDs.contains(event.id) {
                if !numberTerm.isEmpty && term.isEmpty {
                    matchedBy = "Number match"
                } else {
                    matchedBy = "Match"
                }
            } else {
                matchedBy = "Filtered"
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
