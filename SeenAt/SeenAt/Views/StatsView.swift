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
        let withPlayer = events.flatMap { $0.sightings }.filter { !$0.displayName.isEmpty }
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
        ScrollView {
            VStack(spacing: 20) {
                if totalGames == 0 {
                    emptyState
                } else {
                    totalGamesCard
                    byTeamCard
                    byLeagueCard
                    topPlayersCard
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

    private var totalGamesCard: some View {
        HStack(spacing: 24) {
            VStack(spacing: 4) {
                Text("\(totalGames)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Games Tracked")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(width: 1, height: 60)
                .background(.white.opacity(0.3))

            VStack(spacing: 4) {
                Text("\(totalSightings)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Jerseys Seen")
                    .font(.subheadline)
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

    private var byTeamCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Team")
                .font(.headline)

            ChartToggle(usePieChart: $showPieChart)

            if showPieChart {
                Chart(teamTotals, id: \.team.id) { team, count in
                    SectorMark(
                        angle: .value("Count", count),
                        innerRadius: .ratio(0.5),
                        angularInset: 2
                    )
                    .foregroundStyle(team.primaryColor)
                    .annotation(position: .overlay) {
                        Text("\(count)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                }
                .frame(height: 220)
            } else {
                ForEach(teamTotals, id: \.team.id) { team, count in
                    TeamBarRow(team: team, count: count, total: totalSightings)

                    if team != teamTotals.last?.team {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private var byLeagueCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By League")
                .font(.headline)

            ForEach(leagueTotals, id: \.sport) { sport, count in
                HStack {
                    Image(systemName: Team.sportIcon(for: sport))
                        .foregroundStyle(sportColor(sport))
                        .font(.system(size: 14))
                        .frame(width: 16, height: 16)

                    Text(sport)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Text("\(count)")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)

                    Text("jerseys")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if sport != leagueTotals.last?.sport {
                    Divider()
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private var topPlayersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Players")
                .font(.headline)

            ForEach(Array(topPlayers.enumerated()), id: \.element.name) { index, player in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(player.team.primaryColor)
                        .frame(width: 4)
                        .clipShape(RoundedRectangle(cornerRadius: 2))

                    HStack(spacing: 8) {
                        Text("\(index + 1).")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(width: 24, alignment: .leading)

                        Text(player.team.abbreviation)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("(\(player.team.sport.uppercased()))")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        if let number = player.playerNumber, !number.isEmpty {
                            Text("#\(number)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if !player.name.hasPrefix("#") {
                            Text(player.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }

                        Spacer()

                        Text("\(player.count)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(player.team.primaryColor)
                    }
                    .padding(.leading, 8)
                }

                if player.name != topPlayers.last?.name {
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
