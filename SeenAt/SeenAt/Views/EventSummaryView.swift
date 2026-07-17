import SwiftUI
import SwiftData
import Charts

struct EventSummaryView: View {
    @Bindable var event: Event
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var showingAddSighting = false
    @State private var showLiveTracking = false
    @State private var expandedTeams: Set<PersistentIdentifier> = []
    @State private var lastIncrementTimes: [String: Date] = [:]
    @State private var showPieChart = false
    @State private var showShareOptions = false
    @State private var shareContent: ShareContent?
    @State private var showingDeleteError = false

    var topTeamColors: [Color] {
        let teams = event.teamBreakdown.prefix(2).map { $0.team.primaryColor }
        return teams.isEmpty ? [Color.accentColor] : teams
    }

    private var relevantTeams: [Team] {
        let names = [event.homeTeam, event.awayTeam].compactMap { $0 }
        guard !names.isEmpty else { return [] }
        let descriptor = FetchDescriptor<Team>(
            predicate: #Predicate<Team> { names.contains($0.name) }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private var awayTeamColor: Color? {
        guard let name = event.awayTeam else { return nil }
        return relevantTeams.first { $0.name == name }?.primaryColor
    }

    private var homeTeamColor: Color? {
        guard let name = event.homeTeam else { return nil }
        return relevantTeams.first { $0.name == name }?.primaryColor
    }

    var body: some View {
        let teamBreakdown = event.teamBreakdown
        let playerBreakdown = event.playerBreakdown
        let topColors = teamBreakdown.prefix(2).map { $0.team.primaryColor }
        let topTeamColors = topColors.isEmpty ? [Color.accentColor] : topColors

        ScrollView {
            VStack(spacing: 20) {
                totalCountCard(topTeamColors: topTeamColors)

                addSightingButton

                if Calendar.current.isDateInToday(event.date) {
                    liveTrackingButton
                }

                if !teamBreakdown.isEmpty {
                    teamBreakdownCard(teamBreakdown: teamBreakdown)
                }

                if !playerBreakdown.isEmpty {
                    playerBreakdownCard(playerBreakdown: playerBreakdown)
                }

                if !event.sightings.isEmpty, event.watchLocation != .tv {
                    photoGallery
                }

                shareButton
            }
            .padding()
        }
        .navigationTitle("Summary")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddSighting = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .navigationDestination(isPresented: $showLiveTracking) {
            LiveTrackingView(event: event)
        }
        .sheet(isPresented: $showingAddSighting) {
            NavigationStack {
                AddSightingView(event: event)
            }
        }
        .sheet(item: $shareContent) { content in
            ActivityViewController(items: content.activityItems)
        }
        .alert("Delete Failed", isPresented: $showingDeleteError) {
            Button("OK") { }
        } message: {
            Text("Could not delete the sighting. Please try again.")
        }
    }

    private var addSightingButton: some View {
        Button {
            showingAddSighting = true
        } label: {
            Label("Add Sighting", systemImage: "plus.circle.fill")
                .font(.urbanist(.title3, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
    }

    private var liveTrackingButton: some View {
        Button {
            showLiveTracking = true
        } label: {
            Label("Live Tracking", systemImage: "antenna.radiowaves.left.and.right")
                .font(.urbanist(.title3, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
    }

    private func totalCountCard(topTeamColors: [Color]) -> some View {
        VStack(spacing: 8) {
            let countOutline = topTeamColors.first?.opacity(0.5) ?? .black.opacity(0.15)
            Text("\(event.totalCount)")
                .font(.urbanist(size: 64, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: countOutline, radius: 2, x: 1, y: 1)

            Text("Total Jerseys Seen")
                .font(.urbanist(.title3))
                .foregroundStyle(.white.opacity(0.85))

            Text(event.title)
                .font(.urbanist(.subheadline))
                .foregroundStyle(.white.opacity(0.7))

            if let venue = event.venue {
                if event.watchLocation == .tv {
                    Label("Watching on TV · \(venue)", systemImage: "tv")
                        .font(.urbanist(.caption))
                        .foregroundStyle(.white.opacity(0.8))
                } else {
                    Button {
                        openInMaps(venue: venue)
                    } label: {
                        Label(venue, systemImage: "mappin")
                            .font(.urbanist(.caption))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
            }

            if let url = event.gameUrl, let link = URL(string: url) {
                Link(destination: link) {
                    Label("Match Stats", systemImage: "safari")
                        .font(.urbanist(.caption))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background {
            ZStack {
                if event.watchLocation != .tv, let venue = event.venue, let photo = StadiumPhotoService.image(for: venue) {
                    photo
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                    Color.black.opacity(0.5)
                } else {
                    LinearGradient(
                        colors: topTeamColors.map { $0.opacity(0.5) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func teamBreakdownCard(teamBreakdown: [(team: Team, count: Int)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Team")
                .font(.urbanist(.headline))

            ChartToggle(usePieChart: $showPieChart)

            if showPieChart {
                TeamPieChart(breakdown: teamBreakdown)
            } else {
                ForEach(teamBreakdown, id: \.team.id) { team, count in
                    let isExpanded = expandedTeams.contains(team.id)

                    VStack(spacing: 8) {
                        Button {
                            withAnimation(.snappy) {
                                if isExpanded {
                                    expandedTeams.remove(team.id)
                                } else {
                                    expandedTeams.insert(team.id)
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                TeamBarRow(team: team, count: count, total: event.totalCount)
                                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                    .font(.urbanist(.caption))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)

                        if isExpanded {
                            let players = event.players(for: team)
                            if players.isEmpty {
                                Text("No names recorded")
                                    .font(.urbanist(.caption))
                                    .foregroundStyle(.tertiary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 4)
                            } else {
                                VStack(spacing: 6) {
                                    ForEach(players, id: \.playerName) { name, count in
                                        HStack(spacing: 8) {
                                            Circle()
                                                .fill(team.primaryColor)
                                                .frame(width: 8, height: 8)

                                            Text(name)
                                                .font(.urbanist(.subheadline))

                                            if count > 1 {
                                                Text("\(count)x")
                                                    .font(.urbanist(.caption))
                                                    .foregroundStyle(.secondary)
                                            }

                                            Spacer()

                                            Button {
                                                EventActionHandler.incrementPlayer(team: team, name: name, event: event, context: context, lastIncrementTimes: &lastIncrementTimes)
                                            } label: {
                                                Image(systemName: "plus.circle")
                                                    .font(.urbanist(.title3))
                                                    .foregroundStyle(team.primaryColor)
                                            }
                                            .buttonStyle(.plain)
                                            .disabled(EventActionHandler.disabledForDebounce(team: team, name: name, lastIncrementTimes: lastIncrementTimes))
                                        }
                                        .padding(.leading, 20)
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                if !EventActionHandler.deletePlayer(team: team, name: name, event: event, context: context) {
                                                    showingDeleteError = true
                                                }
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if team != teamBreakdown.last?.team {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    @ViewBuilder
    private func playerBreakdownCard(playerBreakdown: [(team: Team, playerName: String, count: Int)]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Player")
                .font(.urbanist(.headline))

            ForEach(playerBreakdown, id: \.playerName) { team, name, count in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(team.primaryColor)
                        .frame(width: 4)
                        .clipShape(RoundedRectangle(cornerRadius: 2))

                    HStack {
                        Text(team.abbreviation)
                            .font(.urbanist(.caption))
                            .foregroundStyle(.secondary)

                        Text(name)
                            .font(.urbanist(.subheadline))

                        Spacer()

                        Text("\(count)")
                            .font(.urbanist(.subheadline, weight: .bold))
                            .foregroundStyle(team.primaryColor)
                    }
                    .padding(.leading, 8)
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    @ViewBuilder
    private var photoGallery: some View {
        let sightingsWithPhotos = event.sightings.filter { $0.photoData != nil }
        if !sightingsWithPhotos.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Photos")
                    .font(.urbanist(.headline))

                LazyVGrid(columns: [.init(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                    ForEach(sightingsWithPhotos, id: \.persistentModelID) { sighting in
                        VStack(spacing: 4) {
                            if let data = sighting.photoData, let image = PhotoCacheService.image(for: sighting.persistentModelID.description, data: data) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            Text(sighting.displayName)
                                .font(.urbanist(.caption2))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding()
            .background(.background, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        }
    }

    private func openInMaps(venue: String) {
        let info = VenueDirectory.info(for: venue)
        let lat = info?.latitude ?? 0
        let lon = info?.longitude ?? 0
        let name = info?.name ?? venue
        var components = URLComponents()
        components.scheme = "maps"
        components.queryItems = [
            URLQueryItem(name: "ll", value: "\(lat),\(lon)"),
            URLQueryItem(name: "q", value: name),
        ]
        guard let url = components.url else { return }
        UIApplication.shared.open(url)
    }

    private var shareButton: some View {
        Button {
            showShareOptions = true
        } label: {
            Label("Share Summary", systemImage: "square.and.arrow.up")
                .font(.urbanist(.headline))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .confirmationDialog("Share Summary", isPresented: $showShareOptions) {
            Button("Share as Text") {
                shareContent = .text(ExportService.generateSummary(for: event))
            }
            Button("Square Image (1080×1080)") {
                guard let image = ExportService.generateSummaryImage(for: event, awayTeamColor: awayTeamColor, homeTeamColor: homeTeamColor, size: CGSize(width: 1080, height: 1080)) else { return }
                shareContent = .image(image)
            }
            Button("Landscape Image (1200×630)") {
                guard let image = ExportService.generateSummaryImage(for: event, awayTeamColor: awayTeamColor, homeTeamColor: homeTeamColor, size: CGSize(width: 1200, height: 630)) else { return }
                shareContent = .image(image)
            }
            Button("Portrait Image (1080×1920)") {
                guard let image = ExportService.generateSummaryImage(for: event, awayTeamColor: awayTeamColor, homeTeamColor: homeTeamColor, size: CGSize(width: 1080, height: 1920)) else { return }
                shareContent = .image(image)
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

enum ShareContent: Identifiable {
    case text(String)
    case image(UIImage)

    var id: String {
        switch self {
        case .text: "text"
        case .image: "image"
        }
    }

    var activityItems: [Any] {
        switch self {
        case .text(let text): return [text]
        case .image(let image): return [image]
        }
    }
}
