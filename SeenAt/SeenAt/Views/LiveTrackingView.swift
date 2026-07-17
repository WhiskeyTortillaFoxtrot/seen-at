import SwiftUI
import SwiftData
import Charts

struct LiveTrackingView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var event: Event
    @Environment(\.modelContext) private var context

    @State private var showingAddSighting = false
    @State private var showingSummary = false
    @State private var expandedSighting: JerseySighting?
    @State private var fullScreenSighting: JerseySighting?
    @State private var showPieChart = false
    @State private var showShareOptions = false
    @State private var shareContent: ShareContent?

    private var relevantTeams: [Team] {
        let names = [event.homeTeam, event.awayTeam].compactMap { $0 }
        guard !names.isEmpty else { return [] }
        let descriptor = FetchDescriptor<Team>(
            predicate: #Predicate<Team> { names.contains($0.name) }
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    var homeTeamColor: Color {
        guard let name = event.homeTeam else { return .white }
        return relevantTeams.first { $0.name == name }?.primaryColor ?? .white
    }

    var homeTeamSecondaryColor: Color {
        guard let name = event.homeTeam else { return .accentColor }
        return relevantTeams.first { $0.name == name }?.secondaryColor ?? .accentColor
    }

    var awayTeamColor: Color? {
        guard let name = event.awayTeam else { return nil }
        return relevantTeams.first { $0.name == name }?.primaryColor
    }

    var body: some View {
        VStack(spacing: 0) {
            headerSection

            if event.sightings.isEmpty {
                emptyState
            } else {
                List {
                    teamBreakdownSection
                    recentSightingsSection
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Live Tracking")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showShareOptions = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Finish") {
                    Task {
                        await LiveActivityManager.end(for: event)
                        showingSummary = true
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddSighting) {
            NavigationStack {
                AddSightingView(event: event)
            }
        }
        .navigationDestination(isPresented: $showingSummary) {
            EventSummaryView(event: event)
        }
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
        .sheet(item: $shareContent) { content in
            ActivityViewController(items: content.activityItems)
        }
        .onChange(of: event.sightings.count) { _, _ in
            Task {
                await LiveActivityManager.startOrUpdate(for: event, teams: relevantTeams)
            }
        }
        .fullScreenCover(item: $fullScreenSighting) { sighting in
            if let data = sighting.photoData, let image = PhotoCacheService.image(for: sighting.persistentModelID.description, data: data) {
                FullScreenPhotoView(image: image)
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text(event.title)
                .font(.urbanist(.title3, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .shadow(radius: 1)

            if let venue = event.venue {
                if event.watchLocation == .tv {
                    Label("Watching on TV · \(venue)", systemImage: "tv")
                        .font(.urbanist(.subheadline))
                        .foregroundStyle(.white.opacity(0.7))
                } else {
                    Text(venue)
                        .font(.urbanist(.subheadline))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            Text("\(event.totalCount)")
                .font(.urbanist(size: 72, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: homeTeamColor.opacity(0.6), radius: 2, x: 1, y: 1)
                .shadow(color: homeTeamColor.opacity(0.3), radius: 8, y: 4)
                .contentTransition(.numericText())

            Text("jerseys spotted")
                .font(.urbanist(.subheadline))
                .foregroundStyle(.white.opacity(0.8))

            Button {
                showingAddSighting = true
            } label: {
                Label("Add Sighting", systemImage: "plus.circle.fill")
                    .font(.urbanist(.title2, weight: .semibold))
                    .frame(maxWidth: 280, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.white)
            .foregroundStyle(homeTeamColor.isLight ? .black : homeTeamColor)
            .padding(.top, 4)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                if event.watchLocation != .tv, let venue = event.venue, let photo = StadiumPhotoService.image(for: venue) {
                    photo
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                    Color.black.opacity(0.5)
                } else {
                    homeTeamSecondaryColor
                        .overlay(Color.black.opacity(0.3))
                }
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Tap the button to log your first jersey!",
            systemImage: "tshirt",
            description: Text("Select the team and optionally add the player's name and a photo.")
        )
    }

    @ViewBuilder
    private var teamBreakdownSection: some View {
        let breakdown = event.teamBreakdown
        let total = event.totalCount
        if !breakdown.isEmpty {
            Section {
                ChartToggle(usePieChart: $showPieChart)
                    .padding(.vertical, 4)

                if showPieChart {
                    TeamPieChart(breakdown: breakdown)
                } else {
                    ForEach(breakdown, id: \.team.id) { team, count in
                        TeamBarRow(team: team, count: count, total: total)
                    }
                }
            } header: {
                Text("By Team")
                    .font(.urbanist(.headline))
            }
        }
    }

    @ViewBuilder
    private var recentSightingsSection: some View {
        let recent = event.sightings.sorted { $0.timestamp > $1.timestamp }
        if !recent.isEmpty {
            Section {
                ForEach(recent.prefix(20)) { sighting in
                    let hasPhoto = event.watchLocation != .tv && sighting.photoData != nil
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Rectangle()
                                .fill(sighting.team?.primaryColor ?? .gray)
                                .frame(width: 4)

                            HStack {
                                if let team = sighting.team {
                                    Text(team.abbreviation)
                                        .font(.urbanist(.subheadline, weight: .medium))
                                }

                                if hasPhoto, let data = sighting.photoData, let image = PhotoCacheService.image(for: sighting.persistentModelID.description, data: data) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 36, height: 36)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                } else {
                                    Image(systemName: "tshirt")
                                        .font(.urbanist(.title3))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 36, height: 36)
                                }

                                if !sighting.displayName.isEmpty {
                                    Text(sighting.displayName)
                                        .font(.urbanist(.subheadline))
                                }

                                Spacer()

                                Text(sighting.timestamp, style: .time)
                                    .font(.urbanist(.caption))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.leading, 8)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if hasPhoto {
                                withAnimation(.snappy) {
                                    if expandedSighting == sighting {
                                        expandedSighting = nil
                                    } else {
                                        expandedSighting = sighting
                                    }
                                }
                            }
                        }

                        if expandedSighting == sighting, hasPhoto, let data = sighting.photoData, let image = PhotoCacheService.image(for: sighting.persistentModelID.description, data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 300)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    fullScreenSighting = sighting
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
            } header: {
                Text("Recent")
                    .font(.urbanist(.headline))
            }
        }
    }
}

struct TeamBarRow: View {
    let team: Team
    let count: Int
    let total: Int

    var fraction: Double {
        total > 0 ? Double(count) / Double(total) : 0
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: team.sportIcon)
                .foregroundStyle(team.primaryColor)
                .font(.urbanist(size: 20))
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(team.name)
                    .font(.urbanist(.subheadline, weight: .medium))

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.quaternary)
                            .frame(height: 8)

                        RoundedRectangle(cornerRadius: 4)
                            .fill(team.primaryColor)
                            .frame(width: max(geo.size.width * fraction, 8), height: 8)
                    }
                }
                .frame(height: 8)
            }

            Text("\(count)")
                .font(.urbanist(.title3, weight: .bold))
                .foregroundStyle(team.primaryColor)
                .frame(minWidth: 32, alignment: .trailing)
        }
    }
}

struct FullScreenPhotoView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Color.black
            .ignoresSafeArea()
            .overlay {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding()
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.urbanist(.title))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding()
                }
            }
            .onTapGesture {
                dismiss()
            }
    }
}
