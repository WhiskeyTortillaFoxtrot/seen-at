import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.modelContext) private var context
    @State private var searchText = ""
    @State private var results: [SearchResult] = []
    @State private var hasSearched = false
    @State private var filters = SearchFilters()

    private let leagues: [(id: String, label: String)] = [
        ("mlb", "MLB"), ("nba", "NBA"), ("wnba", "WNBA"), ("nfl", "NFL"),
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
                HStack {
                    Button {
                        withAnimation { filters.showFilters.toggle() }
                    } label: {
                        HStack(spacing: 4) {
                            Label(
                                filters.showFilters ? "Hide Filters" : "Filters",
                                systemImage: "line.3.horizontal.decrease.circle"
                            )
                            .font(.urbanist(.caption))
                            if filters.activeFilterCount > 0 {
                                Text("\(filters.activeFilterCount)")
                                    .font(.urbanist(.caption2, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.blue))
                            }
                            Image(systemName: filters.showFilters ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                        }
                    }
                    .accessibilityLabel(filters.activeFilterCount > 0 ? "Filters, \(filters.activeFilterCount) active" : "Filters")

                    Spacer()

                    if filters.hasActiveFilters {
                        Button("Clear all") {
                            let showFilters = filters.showFilters
                            filters = SearchFilters()
                            filters.showFilters = showFilters
                            performSearch()
                        }
                        .font(.urbanist(.caption))
                        .foregroundStyle(.blue)
                    }
                }

                if filters.showFilters {
                    VStack(spacing: 8) {
                        Picker("League", selection: $filters.league) {
                            Text("All").tag(nil as String?)
                            ForEach(leagues, id: \.id) { league in
                                Text(league.label).tag(league.id as String?)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: filters.league) { performSearch() }

                        Picker("Location", selection: $filters.watchLocation) {
                            Text("All").tag(nil as WatchLocation?)
                            Text("Stadium").tag(WatchLocation.stadium as WatchLocation?)
                            Text("TV").tag(WatchLocation.tv as WatchLocation?)
                        }
                        .pickerStyle(.menu)
                        .onChange(of: filters.watchLocation) { performSearch() }

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
                                    .onChange(of: filters.dateRangeStart) {
                                        if filters.dateRangeStart > filters.dateRangeEnd {
                                            filters.dateRangeEnd = filters.dateRangeStart
                                        }
                                        performSearch()
                                    }
                                DatePicker("To", selection: $filters.dateRangeEnd, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .onChange(of: filters.dateRangeEnd) {
                                        if filters.dateRangeEnd < filters.dateRangeStart {
                                            filters.dateRangeStart = filters.dateRangeEnd
                                        }
                                        performSearch()
                                    }
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
                    .scrollContentBackground(.hidden)
                    .listRowBackground(GlassListRowBackground())
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
        .toolbarBackground(.hidden, for: .navigationBar)
        .background { StadiumBackdrop(usesDailyImage: true) }
    }

    private var resultsDescription: Text {
        if filters.hasActiveFilters {
            Text("No games match your search and filter criteria")
        } else {
            Text("Try a different search term")
        }
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
        let outcome = SearchQueryService.search(term: term, numberTerm: numberTerm, filters: filters, context: context)

        results = outcome.events.map { event in
            let matchedBy: String
            if outcome.matchedEventIDs.contains(event.id) {
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
