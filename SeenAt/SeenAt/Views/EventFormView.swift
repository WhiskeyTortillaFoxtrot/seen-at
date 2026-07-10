import SwiftUI
import SwiftData

struct EventFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Team.name) private var allTeams: [Team]

    private var teamsForSelectedLeague: [Team] {
        allTeams.filter { $0.sport == selectedLeague }
    }

    @AppStorage("favoriteTeams") private var favoriteTeamsString: String = ""
    private var favoriteTeamNames: [String] {
        favoriteTeamsString.split(separator: ",").map(String.init).filter { !$0.isEmpty }
    }

    @State private var selectedLeague: String = "mlb"
    @State private var date: Date = .now
    @State private var games: [LeagueGame] = []
    @State private var isLoading = false
    @State private var hasFetched = false
    @State private var errorMessage: String?

    @State private var showManualEntry = false
    @State private var selectedAwayTeam: Team?
    @State private var selectedHomeTeam: Team?
    @State private var manualAwayTeamText: String = ""
    @State private var manualHomeTeamText: String = ""
    @State private var manualVenue: String = ""
    @State private var watchLocation: WatchLocation = .stadium

    let onSave: ((Event) -> Void)?

    private let leagues: [(id: String, label: String)] = [
        ("mlb", "MLB"),
        ("nba", "NBA"),
        ("nfl", "NFL"),
        ("nhl", "NHL"),
    ("lovb", "LOVB"),
    ("mls", "MLS"),
    ("other", "Other"),
]

    var body: some View {
        Form {
            Section {
                Picker("Sport", selection: $selectedLeague) {
                    ForEach(leagues, id: \.id) { league in
                        Text(league.label).tag(league.id)
                    }
                }
                .pickerStyle(.menu)

                DatePicker("Game Date", selection: $date, displayedComponents: .date)
                    .onChange(of: date) { _, _ in fetchGames() }
                    .onChange(of: selectedLeague) { _, _ in fetchGames() }
            }

            Section("Watch Location") {
                Picker("", selection: $watchLocation) {
                    Text("🏟️ At the Stadium").tag(WatchLocation.stadium)
                    Text("📺 On TV").tag(WatchLocation.tv)
                }
                .pickerStyle(.segmented)
            }

            gamesSection

            manualEntrySection
        }
        .navigationTitle("New Game")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
        }
        .onAppear { fetchGames() }
    }

    @ViewBuilder
    private var gamesSection: some View {
        let leagueLabel = leagues.first(where: { $0.id == selectedLeague })?.label ?? "Games"
        let sportIcon = Team.sportIcon(for: selectedLeague)

        if isLoading {
            Section {
                HStack { Spacer(); ProgressView("Loading..."); Spacer() }
                    .listRowBackground(Color.clear)
            } header: {
                Label("\(leagueLabel) Games", systemImage: sportIcon)
            }
        } else if let error = errorMessage {
            Section {
                VStack(spacing: 8) {
                    Label(error, systemImage: "wifi.slash")
                        .foregroundStyle(.secondary)
                    Button("Retry") { fetchGames() }
                        .font(.urbanist(.subheadline))
                }
            } header: {
                Label("\(leagueLabel) Games", systemImage: sportIcon)
            }
        } else if hasFetched && games.isEmpty {
            Section {
                Text("No games scheduled for this date")
                    .foregroundStyle(.secondary)
            } header: {
                Label("\(leagueLabel) Games", systemImage: sportIcon)
            }
        } else if !games.isEmpty {
            Section {
                ForEach(sortedGames(games, favoriteTeamNames: favoriteTeamNames)) { game in
                    Button {
                        createEvent(from: game)
                    } label: {
                        LeagueGameRow(
                            game: game,
                            isFavorite: favoriteTeamNames.contains { game.awayTeam.localizedCaseInsensitiveContains($0) || game.homeTeam.localizedCaseInsensitiveContains($0) }
                        )
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Label("\(leagueLabel) Games", systemImage: sportIcon)
            }
        }
    }

    private var manualEntrySection: some View {
        Section {
            DisclosureGroup("Or Enter Manually", isExpanded: $showManualEntry) {
                if selectedLeague != "other" {
                    Picker("Away Team", selection: $selectedAwayTeam) {
                        Text("Choose...").tag(nil as Team?)
                        ForEach(teamsForSelectedLeague) { team in
                            HStack {
                                Circle()
                                    .fill(team.primaryColor)
                                    .frame(width: 12, height: 12)
                                Text(team.name)
                            }
                            .tag(team as Team?)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Home Team", selection: $selectedHomeTeam) {
                        Text("Choose...").tag(nil as Team?)
                        ForEach(teamsForSelectedLeague) { team in
                            HStack {
                                Circle()
                                    .fill(team.primaryColor)
                                    .frame(width: 12, height: 12)
                                Text(team.name)
                            }
                            .tag(team as Team?)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedHomeTeam) { _, newTeam in
                        if let team = newTeam, let venue = VenueDirectory.homeVenue(for: team.name) {
                            manualVenue = venue
                        }
                    }
                } else {
                    TextField("Away Team", text: $manualAwayTeamText)
                    TextField("Home Team", text: $manualHomeTeamText)
                }

                TextField("Venue (optional)", text: $manualVenue)
                Button("Start Tracking") {
                    saveManual()
                }
                .font(.urbanist(.headline))
                .frame(maxWidth: .infinity)
                .disabled(manualTeamsDisabled)
            }
        }
    }

    private var manualTeamsDisabled: Bool {
        if selectedLeague != "other" {
            selectedAwayTeam == nil || selectedHomeTeam == nil
        } else {
            manualAwayTeamText.trimmingCharacters(in: .whitespaces).isEmpty ||
            manualHomeTeamText.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private func fetchGames() {
        isLoading = true
        errorMessage = nil
        hasFetched = false

        Task {
            do {
                let fetched: [LeagueGame]
                switch selectedLeague {
                case "nhl":
                    fetched = try await NHLAPIService.fetchGames(on: date)
                case "nba":
                    fetched = try await ESPNService.fetchGames(on: date, sportPath: "basketball/nba")
                case "nfl":
                    fetched = try await ESPNService.fetchGames(on: date, sportPath: "football/nfl")
        case "lovb", "mls", "other":
            fetched = []
        default:
            fetched = try await MLBAPIService.fetchGames(on: date)
                }
                await MainActor.run {
                    games = fetched
                    isLoading = false
                    hasFetched = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Could not load games"
                    isLoading = false
                    hasFetched = true
                }
            }
        }
    }

    private func createEvent(from game: LeagueGame) {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let gameDate = dateFormatter.date(from: game.dateString) ?? date

        let event = Event(
            awayTeam: game.awayTeam,
            homeTeam: game.homeTeam,
            date: gameDate,
            venue: game.venueName,
            gameUrl: game.url?.absoluteString,
            watchLocation: watchLocation
        )
        context.insert(event)
        try? context.save()
        onSave?(event)
    }

    private func saveManual() {
        let event: Event
        if selectedLeague != "other", let away = selectedAwayTeam, let home = selectedHomeTeam {
            event = Event(
                awayTeam: away.name,
                homeTeam: home.name,
                date: date,
                venue: manualVenue.trimmingCharacters(in: .whitespaces).isEmpty ? nil : manualVenue.trimmingCharacters(in: .whitespaces),
                watchLocation: watchLocation
            )
        } else {
            event = Event(
                awayTeam: manualAwayTeamText.trimmingCharacters(in: .whitespaces),
                homeTeam: manualHomeTeamText.trimmingCharacters(in: .whitespaces),
                date: date,
                venue: manualVenue.trimmingCharacters(in: .whitespaces).isEmpty ? nil : manualVenue.trimmingCharacters(in: .whitespaces),
                watchLocation: watchLocation
            )
        }
        context.insert(event)
        try? context.save()
        onSave?(event)
    }
}

struct LeagueGameRow: View {
    let game: LeagueGame
    var isFavorite: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(game.title)
                .font(.urbanist(.headline))
                .foregroundStyle(.primary)

            HStack(spacing: 8) {
                Label(game.venueName, systemImage: "mappin")
                    .font(.urbanist(.caption))
                    .foregroundStyle(.secondary)

                if let dayNight = game.dayNight {
                    Text(dayNight == "day" ? "Day Game" : "Night Game")
                        .font(.urbanist(.caption))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .overlay(alignment: .topTrailing) {
            if isFavorite {
                Image(systemName: "star.fill")
                    .font(.urbanist(.caption2))
                    .foregroundStyle(.yellow)
                    .offset(x: 4, y: -4)
            }
        }
    }
}
