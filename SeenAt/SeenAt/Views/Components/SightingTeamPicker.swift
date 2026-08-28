import SwiftUI

struct SightingLeague: Identifiable {
    let id: String
    let label: String
}

let sightingLeagueOptions = [
    SightingLeague(id: "mlb", label: "MLB"),
    SightingLeague(id: "nba", label: "NBA"),
    SightingLeague(id: "nfl", label: "NFL"),
    SightingLeague(id: "nhl", label: "NHL"),
    SightingLeague(id: "lovb", label: "LOVB"),
    SightingLeague(id: "mls", label: "MLS"),
    SightingLeague(id: "nwsl", label: "NWSL"),
]

struct SightingTeamPicker: View {
    let homeTeamName: String?
    let awayTeamName: String?
    let allTeams: [Team]
    let favoriteTeamNames: [String]
    @Binding var selectedTeam: Team?
    @Binding var selectedLeague: SightingLeague?

    private var eventGameTeams: [Team] {
        let names = [homeTeamName, awayTeamName].compactMap { $0 }
        return allTeams.filter { names.contains($0.name) }
            .sorted { (names.firstIndex(of: $0.name) ?? 0) < (names.firstIndex(of: $1.name) ?? 0) }
    }

    private var eventLeague: String? {
        eventGameTeams.first?.sport ?? eventGameTeams.last?.sport
    }

    private var eventLeagueNonGameTeams: [Team] {
        guard let eventLeague else { return [] }
        let gameTeamNames = Set(eventGameTeams.map(\.name))
        return sortedFavoritesFirst(allTeams.filter {
            $0.sport == eventLeague && !gameTeamNames.contains($0.name)
        })
    }

    private var otherLeagues: [SightingLeague] {
        sightingLeagueOptions.filter { league in
            league.id != eventLeague && allTeams.contains { $0.sport == league.id }
        }
    }

    // An event without identifiable game teams should not offer empty leagues.
    private var availableLeagues: [SightingLeague] {
        sightingLeagueOptions.filter { league in allTeams.contains { $0.sport == league.id } }
    }

    var body: some View {
        Menu {
            Button("Choose...") { selectedTeam = nil }
            if !eventGameTeams.isEmpty {
                ForEach(eventGameTeams) { teamButton($0) }
                Divider()
            }
            if eventLeague != nil {
                ForEach(eventLeagueNonGameTeams) { teamButton($0) }
                Divider()
                ForEach(otherLeagues) { league in
                    Button(league.label) { selectedLeague = league }
                }
            } else {
                ForEach(availableLeagues) { league in
                    Button(league.label) { selectedLeague = league }
                }
            }
        } label: {
            HStack {
                Text("Select Team")
                Spacer()
                if let selectedTeam {
                    HStack(spacing: 8) {
                        Circle().fill(selectedTeam.primaryColor).frame(width: 12, height: 12)
                            .accessibilityHidden(true)
                        Text(selectedTeam.name).foregroundStyle(.secondary)
                    }
                } else {
                    Text("Choose...").foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func teamButton(_ team: Team) -> some View {
        Button { selectedTeam = team } label: {
            HStack {
                Circle().fill(team.primaryColor).frame(width: 12, height: 12)
                    .accessibilityHidden(true)
                Text(team.name)
                if favoriteTeamNames.contains(team.name) {
                    Spacer()
                    Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption)
                }
            }
        }
    }

    private func sortedFavoritesFirst(_ teams: [Team]) -> [Team] {
        let favorites = Set(favoriteTeamNames)
        return teams.sorted { lhs, rhs in
            let lhsFavorite = favorites.contains(lhs.name)
            let rhsFavorite = favorites.contains(rhs.name)
            if lhsFavorite != rhsFavorite { return lhsFavorite }
            return lhs.name < rhs.name
        }
    }
}

struct SightingLeaguePicker: View {
    let league: SightingLeague
    let allTeams: [Team]
    let favoriteTeamNames: [String]
    let onSelect: (Team) -> Void
    @Environment(\.dismiss) private var dismiss

    private var leagueTeams: [Team] {
        let favorites = Set(favoriteTeamNames)
        return allTeams.filter { $0.sport == league.id }.sorted { lhs, rhs in
            let lhsFavorite = favorites.contains(lhs.name)
            let rhsFavorite = favorites.contains(rhs.name)
            if lhsFavorite != rhsFavorite { return lhsFavorite }
            return lhs.name < rhs.name
        }
    }

    var body: some View {
        NavigationStack {
            List(leagueTeams) { team in
                Button {
                    onSelect(team)
                    dismiss()
                } label: {
                    HStack {
                        Circle().fill(team.primaryColor).frame(width: 12, height: 12)
                            .accessibilityHidden(true)
                        Text(team.name)
                            .font(favoriteTeamNames.contains(team.name) ? .urbanist(.body, weight: .bold) : .urbanist(.body))
                        if favoriteTeamNames.contains(team.name) {
                            Spacer()
                            Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
            .scrollContentBackground(.hidden)
            .listRowBackground(GlassListRowBackground())
            .background { StadiumBackdrop(usesDailyImage: true) }
            .navigationTitle(league.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } } }
        }
    }
}
