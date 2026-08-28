import SwiftUI
import SwiftData
import Charts
import Combine

struct EventSummaryView: View {
    let event: Event
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var showingAddSighting = false
    @State private var addSightingHaptic = 0
    @State private var showLiveTracking = false
    @State private var liveTrackingHaptic = 0
    @State private var expandedTeams: Set<PersistentIdentifier> = []
    @State private var lastIncrementTimes: [String: Date] = [:]
    @State private var showPieChart = false
    @State private var showShareOptions = false
    @State private var shareContent: ShareContent?
    @State private var showingDeleteError = false
    @State private var deleteErrorHaptic = 0
    @State private var photoSightings: [JerseySighting] = []
    @State private var selectedSighting: JerseySighting?
    @State private var currentDate = Date.now
    @ScaledMetric(relativeTo: .largeTitle) private var heroCountSize: CGFloat = 64

    private var currentWatchLocation: WatchLocation {
        event.watchLocation ?? .stadium
    }

    private var isPreview: Bool {
        EventPreviewPolicy.isReadOnly(event, now: currentDate)
    }

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

        ZStack {
            StadiumBackdrop(venue: event.venue, usesDailyImage: true)

            ScrollView {
                VStack(spacing: 20) {
                    totalCountCard(topTeamColors: topTeamColors)

                    if !isPreview {
                        addSightingButton
                    }

                    if !isPreview, Calendar.current.isDateInToday(event.date) {
                        liveTrackingButton
                    }

                    if !teamBreakdown.isEmpty {
                        teamBreakdownCard(teamBreakdown: teamBreakdown, readOnly: isPreview)
                    }

                    if !playerBreakdown.isEmpty {
                        playerBreakdownCard(playerBreakdown: playerBreakdown)
                    }

                    if !event.sightings.isEmpty, !isPreview {
                        sightingsCard
                    }

                    if event.watchLocation != .tv {
                        photoGallery
                    }

                    shareButton
                }
                .padding()
            }
        }
        .navigationTitle(isPreview ? "Game Preview" : "Summary")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            if !isPreview {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSighting = true
                        addSightingHaptic += 1
                    } label: {
                        Image(systemName: "plus")
                            .accessibilityLabel("Add Sighting")
                    }
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
        .sheet(item: $selectedSighting) { sighting in
            NavigationStack {
                SightingEditorView(sighting: sighting) {
                    photoSightings = event.sightings.filter { $0.photoData != nil }
                    Task { @MainActor in
                        await LiveActivityManager.updateIfActive(for: event, teams: relevantTeams)
                    }
                }
            }
        }
        .sheet(item: $shareContent) { content in
            ActivityViewController(items: content.activityItems)
        }
        .alert("Delete Failed", isPresented: $showingDeleteError) {
            Button("OK") { deleteErrorHaptic += 1 }
        } message: {
            Text("Could not delete the sighting. Please try again.")
        }
        .onAppear { photoSightings = event.sightings.filter { $0.photoData != nil }         }
        .onChange(of: event.sightings.count) { _, _ in
            photoSightings = event.sightings.filter { $0.photoData != nil }
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { date in
            currentDate = date
        }
        .onAppear {
            currentDate = .now
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                currentDate = .now
            }
        }
        .sensoryFeedback(.warning, trigger: deleteErrorHaptic)
    }

    private var addSightingButton: some View {
        Button {
            showingAddSighting = true
            addSightingHaptic += 1
        } label: {
            Label("Add Sighting", systemImage: "plus.circle.fill")
                .font(.urbanist(.title3, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .sensoryFeedback(.impact(weight: .light), trigger: addSightingHaptic)
    }

    private var liveTrackingButton: some View {
        Button {
            showLiveTracking = true
            liveTrackingHaptic += 1
        } label: {
            Label("Live Tracking", systemImage: "antenna.radiowaves.left.and.right")
                .font(.urbanist(.title3, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .sensoryFeedback(.impact(weight: .light), trigger: liveTrackingHaptic)
    }

    private func totalCountCard(topTeamColors: [Color]) -> some View {
        VStack(spacing: 8) {
            let countOutline = topTeamColors.first?.opacity(0.5) ?? .black.opacity(0.15)
            Text("\(event.totalCount)")
                .font(.urbanist(size: heroCountSize, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: countOutline, radius: 2, x: 1, y: 1)

            Text("Total Jerseys Seen")
                .font(.urbanist(.title3))
                .foregroundStyle(.white.opacity(0.85))

            Text(event.title)
                .font(.urbanist(.subheadline))
                .foregroundStyle(.white.opacity(0.7))

            if isPreview {
                Text("Game date: \(event.date.formatted(date: .long, time: .omitted))")
                    .font(.urbanist(.caption))
                    .foregroundStyle(.white.opacity(0.8))
            }

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
            } else if event.watchLocation == .tv {
                Label("On TV", systemImage: "tv")
                    .font(.urbanist(.caption))
                    .foregroundStyle(.white.opacity(0.8))
            } else {
                Label("At the Stadium", systemImage: "mappin")
                    .font(.urbanist(.caption))
                    .foregroundStyle(.white.opacity(0.8))
            }

            if !isPreview {
                locationMenu
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
        .liquidGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var locationMenu: some View {
        Menu {
            Button {
                updateWatchLocation(.stadium)
            } label: {
                Label("At the Stadium", systemImage: currentWatchLocation == .stadium ? "checkmark" : "mappin")
            }
            Button {
                updateWatchLocation(.tv)
            } label: {
                Label("On TV", systemImage: currentWatchLocation == .tv ? "checkmark" : "tv")
            }
        } label: {
            Label("Change watch location", systemImage: "pencil.circle")
                .font(.urbanist(.caption))
                .foregroundStyle(.white.opacity(0.8))
        }
        .accessibilityLabel("Change watch location")
        .accessibilityValue(currentWatchLocation == .tv ? "On TV" : "At the Stadium")
    }

    private func updateWatchLocation(_ location: WatchLocation) {
        let previousLocation = event.watchLocation
        event.watchLocation = location
        if !context.saveAndLog("Failed to update watch location") {
            event.watchLocation = previousLocation
        }
    }

    private func teamBreakdownCard(teamBreakdown: [(team: Team, count: Int)], readOnly: Bool) -> some View {
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
                                                .accessibilityHidden(true)

                                            Text(name)
                                                .font(.urbanist(.subheadline))

                                            if count > 1 {
                                                Text("\(count)x")
                                                    .font(.urbanist(.caption))
                                                    .foregroundStyle(.secondary)
                                            }

                                            Spacer()

                                             if !readOnly {
                                                 Button {
                                                     EventActionHandler.incrementPlayer(team: team, name: name, event: event, context: context, lastIncrementTimes: &lastIncrementTimes)
                                                 } label: {
                                                     Image(systemName: "plus.circle")
                                                         .font(.urbanist(.title3))
                                                         .foregroundStyle(team.primaryColor)
                                                 }
                                                 .buttonStyle(.plain)
                                                 .accessibilityLabel("Add \(name)")
                                                 .disabled(EventActionHandler.disabledForDebounce(team: team, name: name, lastIncrementTimes: lastIncrementTimes))
                                             }
                                         }
                                         .padding(.leading, 20)
                                         .swipeActions(edge: .trailing) {
                                             if !readOnly {
                                                 Button(role: .destructive) {
                                                     if !EventActionHandler.deletePlayer(team: team, name: name, event: event, context: context) {
                                                         showingDeleteError = true
                                                     } else {
                                                         UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
                    }

                    if team != teamBreakdown.last?.team {
                        Divider()
                    }
                }
            }
        }
        .groupedGlassCard()
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
                        .accessibilityHidden(true)

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
        .groupedGlassCard()
    }

    @ViewBuilder
    private var sightingsCard: some View {
        let sightings = event.sightings.sorted { $0.timestamp > $1.timestamp }
        VStack(alignment: .leading, spacing: 12) {
            Text("Sightings")
                .font(.urbanist(.headline))

            ForEach(sightings, id: \.persistentModelID) { sighting in
                Button {
                    selectedSighting = sighting
                } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(sighting.team?.primaryColor ?? .gray)
                            .frame(width: 10, height: 10)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(sighting.displayName.isEmpty ? "Unnamed Sighting" : sighting.displayName)
                                .font(.urbanist(.subheadline))
                            Text(sighting.team?.name ?? "No team")
                                .font(.urbanist(.caption))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(sighting.timestamp, style: .time)
                            .font(.urbanist(.caption))
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.urbanist(.caption))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit \(sighting.displayName.isEmpty ? "sighting" : sighting.displayName)")

                if sighting.persistentModelID != sightings.last?.persistentModelID {
                    Divider()
                }
            }
        }
        .groupedGlassCard()
    }

    @ViewBuilder
    private var photoGallery: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photos")
                .font(.urbanist(.headline))

            if photoSightings.isEmpty {
                Text("No photos yet")
                    .font(.urbanist(.subheadline))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                LazyVGrid(columns: [.init(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                    ForEach(Array(photoSightings), id: \.persistentModelID) { sighting in
                        VStack(spacing: 4) {
                            Button { selectedSighting = sighting } label: {
                                if let data = sighting.photoData, let image = PhotoCacheService.image(for: "\(sighting.persistentModelID)", data: data) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Edit \(sighting.displayName.isEmpty ? "sighting" : sighting.displayName)")
                            Text(sighting.displayName)
                                .font(.urbanist(.caption2))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
        .groupedGlassCard()
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
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
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
