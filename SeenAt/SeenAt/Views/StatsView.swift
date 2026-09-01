import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Query(sort: \Event.date, order: .reverse) private var events: [Event]
    @State private var showPieChart = false
    @State private var selectedYear: Int? = nil
    @State private var trendGranularity: TrendGranularity = .perMonth
    @State private var viewModel = StatsViewModel()
    @ScaledMetric(relativeTo: .largeTitle) private var heroStatSize: CGFloat = 48

    var body: some View {
        let cacheKey = StatsCacheKey(events: events, selectedYear: selectedYear)
        let games = viewModel.totalGames
        let sightings = viewModel.totalSightings
        let teams = viewModel.teamTotals
        let leagues = viewModel.leagueTotals
        let players = viewModel.topPlayers
        let watchLocations = viewModel.watchLocationTotals
        let venues = viewModel.venueTotals

        ScrollView {
            VStack(spacing: 20) {
                if !viewModel.availableYears.isEmpty {
                    Picker("Year", selection: $selectedYear) {
                        Text("All Time").tag(Optional<Int>.none)
                        ForEach(viewModel.availableYears, id: \.self) { year in
                            Text(String(year)).tag(Optional<Int>.some(year))
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if viewModel.hasLoaded && games == 0 {
                    emptyState
                        .transition(.opacity)
                } else {
                    totalGamesCard(games: games, sightings: sightings)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    byTeamCard(teams: teams, sightings: sightings)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    byLeagueCard(leagues: leagues)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    topPlayersCard(players: players)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    StatsTrendChart(events: viewModel.filteredEvents, granularity: $trendGranularity)
                    StatsWatchLocationCard(stadiumCount: watchLocations.stadium, tvCount: watchLocations.tv)
                    StatsVenueCard(venues: venues)
                    StatsStreakCard(events: viewModel.filteredEvents)
                    StatsMilestonesCard(events: viewModel.filteredEvents)
                }
            }
            .padding()
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: games)
        }
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .task(id: cacheKey) {
            viewModel.update(key: cacheKey, events: events)
        }
        .onChange(of: viewModel.availableYears) { _, availableYears in
            if let selectedYear, !availableYears.contains(selectedYear) {
                self.selectedYear = nil
            }
        }
        .background { StadiumBackdrop(usesDailyImage: true) }
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
                    .font(.urbanist(size: heroStatSize, weight: .bold))
                    .foregroundStyle(.white)
                Text("Games Tracked")
                    .font(.urbanist(.subheadline))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(width: 1, height: 60)
                .overlay(.white.opacity(0.3))

            VStack(spacing: 4) {
                Text("\(sightings)")
                    .font(.urbanist(size: heroStatSize, weight: .bold))
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
        .liquidGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
        .liquidGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func topPlayersCard(players: [(name: String, team: Team, playerNumber: String?, count: Int)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Players")
                .font(.urbanist(.headline))

            ForEach(Array(players.enumerated()), id: \.offset) { index, player in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(player.team.primaryColor)
                        .frame(width: 4)
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                        .accessibilityHidden(true)

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
                                .lineLimit(1)
                                .layoutPriority(1)
                        }

                        Spacer()

                        Text("\(player.count)")
                            .font(.urbanist(.subheadline, weight: .bold))
                            .foregroundStyle(player.team.primaryColor)
                    }
                    .padding(.leading, 8)
                }

                if player.team.name != players.last?.team.name || player.name != players.last?.name {
                    Divider()
                }
            }
        }
        .padding()
        .liquidGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func sportColor(_ sport: String) -> Color {
        switch sport {
        case "MLB": return .blue
        case "NBA": return .orange
        case "WNBA": return .purple
        case "NFL": return .green
        case "NHL": return .red
        case "MLS": return .purple
        case "LOVB": return .gray
        case "NWSL": return .teal
        default: return .gray
        }
    }
}
