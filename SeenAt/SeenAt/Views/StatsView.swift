import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Query(sort: \Event.date, order: .reverse) private var events: [Event]
    @State private var showPieChart = false

    var totalGames: Int { events.count }

    var totalSightings: Int {
        events.reduce(0) { $0 + $1.sightings.count }
    }

    var teamTotals: [(team: Team, count: Int)] {
        let allSightings = events.flatMap { $0.sightings.compactMap { $0.team == nil ? nil : $0 } }
        let grouped = Dictionary(grouping: allSightings) { $0.team! }
        return grouped
            .map { ($0.key, $0.value.count) }
            .sorted { a, b in a.count > b.count || (a.count == b.count && a.team.name < b.team.name) }
    }

    var leagueTotals: [(sport: String, count: Int)] {
        let allTeams = events.flatMap { $0.sightings.compactMap { $0.team } }
        let grouped = Dictionary(grouping: allTeams) { $0.sport.uppercased() }
        return grouped
            .map { ($0.key, $0.value.count) }
            .sorted { $0.count > $1.count }
    }

    var topPlayers: [(name: String, team: Team, playerNumber: String?, count: Int)] {
        let withPlayer = events.flatMap { $0.sightings }.filter { $0.isPlayerSighting }
        let grouped = Dictionary(grouping: withPlayer) { "\($0.team?.name ?? ""):\($0.displayName)" }
        return grouped
            .compactMap { (key, values) -> (name: String, team: Team, playerNumber: String?, count: Int)? in
                guard let first = values.first, let team = first.team else { return nil }
                return (first.displayName, team, first.playerNumber, values.count)
            }
            .sorted { a, b in a.count > b.count || (a.count == b.count && a.name < b.name) }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        let games = totalGames
        let sightings = totalSightings
        let teams = teamTotals
        let leagues = leagueTotals
        let players = topPlayers

        ScrollView {
            VStack(spacing: 20) {
                if games == 0 {
                    emptyState
                } else {
                    totalGamesCard(games: games, sightings: sightings)
                    byTeamCard(teams: teams, sightings: sightings)
                    byLeagueCard(leagues: leagues)
                    topPlayersCard(players: players)
                }
            }
            .padding()
        }
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Stats Yet",
            systemImage: "chart.bar",
            description: Text("Start tracking games to see your stats.")
        )
    }

    private func totalGamesCard(games: Int, sightings: Int) -> some View {
        HStack(spacing: 24) {
            VStack(spacing: 4) {
                Text("\(games)")
                    .font(.urbanist(size: 48, weight: .bold))
                    .foregroundStyle(.white)
                Text("Games Tracked")
                    .font(.urbanist(.subheadline))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(width: 1, height: 60)
                .background(.white.opacity(0.3))

            VStack(spacing: 4) {
                Text("\(sightings)")
                    .font(.urbanist(size: 48, weight: .bold))
                    .foregroundStyle(.white)
                Text("Jerseys Seen")
                    .font(.urbanist(.subheadline))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.85), Color.accentColor.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func byTeamCard(teams: [(team: Team, count: Int)], sightings: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Team")
                .font(.urbanist(.headline))

            ChartToggle(usePieChart: $showPieChart)

            if showPieChart {
                TeamPieChart(breakdown: teams)
            } else {
                ForEach(teams, id: \.team.id) { team, count in
                    TeamBarRow(team: team, count: count, total: sightings)

                    if team != teams.last?.team {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private func byLeagueCard(leagues: [(sport: String, count: Int)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By League")
                .font(.urbanist(.headline))

            ForEach(leagues, id: \.sport) { sport, count in
                HStack {
                    Image(systemName: Team.sportIcon(for: sport))
                        .foregroundStyle(sportColor(sport))
                        .font(.urbanist(size: 14))
                        .frame(width: 16, height: 16)

                    Text(sport)
                        .font(.urbanist(.subheadline, weight: .medium))

                    Spacer()

                    Text("\(count)")
                        .font(.urbanist(.subheadline, weight: .bold))
                        .foregroundStyle(.primary)

                    Text("jerseys")
                        .font(.urbanist(.caption))
                        .foregroundStyle(.secondary)
                }

                if sport != leagues.last?.sport {
                    Divider()
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private func topPlayersCard(players: [(name: String, team: Team, playerNumber: String?, count: Int)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Players")
                .font(.urbanist(.headline))

            ForEach(Array(players.enumerated()), id: \.element.name) { index, player in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(player.team.primaryColor)
                        .frame(width: 4)
                        .clipShape(RoundedRectangle(cornerRadius: 2))

                    HStack(spacing: 8) {
                        Text("\(index + 1).")
                            .font(.urbanist(.subheadline))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, alignment: .leading)

                        Text(player.team.abbreviation)
                            .font(.urbanist(.subheadline, weight: .medium))

                        Text("(\(player.team.sport.uppercased()))")
                            .font(.urbanist(.caption))
                            .foregroundStyle(.secondary)

                        if let number = player.playerNumber, !number.isEmpty {
                            Text("#\(number)")
                                .font(.urbanist(.caption))
                                .foregroundStyle(.secondary)
                        }

                        if !player.name.hasPrefix("#") {
                            Text(player.name)
                                .font(.urbanist(.subheadline, weight: .medium))
                        }

                        Spacer()

                        Text("\(player.count)")
                            .font(.urbanist(.subheadline, weight: .bold))
                            .foregroundStyle(player.team.primaryColor)
                    }
                    .padding(.leading, 8)
                }

                if player.name != players.last?.name {
                    Divider()
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private func sportColor(_ sport: String) -> Color {
        switch sport {
        case "MLB": return .blue
        case "NBA": return .orange
        case "NFL": return .green
        case "NHL": return .red
        case "MLS": return .purple
        case "LOVB": return .gray
        default: return .gray
        }
    }
}
