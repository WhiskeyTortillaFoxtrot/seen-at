import SwiftUI

struct EventFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

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
    @State private var manualTitle: String = ""
    @State private var manualVenue: String = ""
    @State private var watchLocation: WatchLocation = .stadium

    let onSave: ((Event) -> Void)?

    private let leagues: [(id: String, label: String)] = [
        ("mlb", "MLB"),
        ("nba", "NBA"),
        ("nfl", "NFL"),
        ("nhl", "NHL"),
        ("lovb", "LOVB"),
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

        if isLoading {
            Section("\(leagueLabel) Games") {
                HStack { Spacer(); ProgressView("Loading..."); Spacer() }
                    .listRowBackground(Color.clear)
            }
        } else if let error = errorMessage {
            Section("\(leagueLabel) Games") {
                VStack(spacing: 8) {
                    Label(error, systemImage: "wifi.slash")
                        .foregroundStyle(.secondary)
                    Button("Retry") { fetchGames() }
                        .font(.subheadline)
                }
            }
        } else if hasFetched && games.isEmpty {
            Section("\(leagueLabel) Games") {
                Text("No games scheduled for this date")
                    .foregroundStyle(.secondary)
            }
        } else if !games.isEmpty {
            Section("\(leagueLabel) Games") {
                ForEach(sortedGames(games, favoriteTeamNames: favoriteTeamNames)) { game in
                    Button {
                        createEvent(from: game)
                    } label: {
                        LeagueGameRow(
                            game: game,
                            isFavorite: favoriteTeamNames.contains { game.title.localizedCaseInsensitiveContains($0) }
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var manualEntrySection: some View {
        Section {
            DisclosureGroup("Or Enter Manually", isExpanded: $showManualEntry) {
                TextField("Title (e.g. Yankees vs Red Sox)", text: $manualTitle)
                TextField("Venue (optional)", text: $manualVenue)
                Button("Start Tracking") {
                    saveManual()
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .disabled(manualTitle.trimmingCharacters(in: .whitespaces).isEmpty)
            }
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
            title: game.title,
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
        let event = Event(
            title: manualTitle.trimmingCharacters(in: .whitespaces),
            date: date,
            venue: manualVenue.trimmingCharacters(in: .whitespaces).isEmpty ? nil : manualVenue.trimmingCharacters(in: .whitespaces),
            watchLocation: watchLocation
        )
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
                .font(.headline)
                .foregroundStyle(.primary)

            HStack(spacing: 8) {
                Label(game.venueName, systemImage: "mappin")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let dayNight = game.dayNight {
                    Text(dayNight == "day" ? "Day Game" : "Night Game")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
        .overlay(alignment: .topTrailing) {
            if isFavorite {
                Image(systemName: "star.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
                    .offset(x: 4, y: -4)
            }
        }
    }
}
