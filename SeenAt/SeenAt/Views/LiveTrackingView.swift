import SwiftUI
import SwiftData
import Charts

struct LiveTrackingView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var event: Event

    @Query(sort: \Team.name) private var allTeams: [Team]

    @State private var showingAddSighting = false
    @State private var showingSummary = false
    @State private var expandedSighting: JerseySighting?
    @State private var fullScreenSighting: JerseySighting?
    @State private var showPieChart = false

    var homeTeamColor: Color {
        guard let name = event.homeTeam else { return .white }
        return allTeams.first { $0.name == name }?.primaryColor ?? .white
    }

    var homeTeamSecondaryColor: Color {
        guard let name = event.homeTeam else { return .accentColor }
        return allTeams.first { $0.name == name }?.secondaryColor ?? .accentColor
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
            ToolbarItem(placement: .topBarTrailing) {
                if !event.sightings.isEmpty {
                    Button("Finish") {
                        Task {
                            await LiveActivityManager.end(for: event)
                            showingSummary = true
                        }
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
        .onChange(of: event.sightings.count) { _, _ in
            Task {
                await LiveActivityManager.startOrUpdate(for: event, teams: allTeams)
            }
        }
        .fullScreenCover(item: $fullScreenSighting) { sighting in
            if let data = sighting.photoData, let image = UIImage(data: data) {
                FullScreenPhotoView(image: image)
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            Text(event.title)
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
                .shadow(radius: 1)

            if let venue = event.venue {
                if event.watchLocation == .tv {
                    Label("Watching on TV · \(venue)", systemImage: "tv")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                } else {
                    Text(venue)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            Text("\(event.totalCount)")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: homeTeamColor.opacity(0.6), radius: 2, x: 1, y: 1)
                .shadow(color: homeTeamColor.opacity(0.3), radius: 8, y: 4)
                .contentTransition(.numericText())

            Text("jerseys spotted")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))

            Button {
                showingAddSighting = true
            } label: {
                Label("Add Sighting", systemImage: "plus.circle.fill")
                    .font(.title2)
                    .fontWeight(.semibold)
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
                    Chart(breakdown, id: \.team.id) { team, count in
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
                    ForEach(breakdown, id: \.team.id) { team, count in
                        TeamBarRow(team: team, count: count, total: total)
                    }
                }
            } header: {
                Text("By Team")
                    .font(.headline)
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
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }

                                if hasPhoto, let data = sighting.photoData, let image = UIImage(data: data) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 36, height: 36)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                } else {
                                    Image(systemName: "tshirt")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 36, height: 36)
                                }

                                if !sighting.displayName.isEmpty {
                                    Text(sighting.displayName)
                                        .font(.subheadline)
                                }

                                Spacer()

                                Text(sighting.timestamp, style: .time)
                                    .font(.caption)
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

                        if expandedSighting == sighting, hasPhoto, let data = sighting.photoData, let image = UIImage(data: data) {
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
                    .font(.headline)
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
                .font(.system(size: 20))
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(team.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

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
                .font(.title3)
                .fontWeight(.bold)
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
                        .font(.title)
                        .foregroundStyle(.white.opacity(0.8))
                        .padding()
                }
            }
            .onTapGesture {
                dismiss()
            }
    }
}
