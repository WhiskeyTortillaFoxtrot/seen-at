import SwiftUI
import SwiftData

struct EventSummaryView: View {
    @Bindable var event: Event
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var showingAddSighting = false
    @State private var showLiveTracking = false
    @State private var expandedTeams: Set<PersistentIdentifier> = []
    @State private var lastIncrementTimes: [String: Date] = [:]

    var topTeamColors: [Color] {
        let teams = event.teamBreakdown.prefix(2).map { $0.team.primaryColor }
        return teams.isEmpty ? [Color.accentColor] : teams
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                totalCountCard

                addSightingButton

                if Calendar.current.isDateInToday(event.date) {
                    liveTrackingButton
                }

                if !event.teamBreakdown.isEmpty {
                    teamBreakdownCard
                }

                if !event.playerBreakdown.isEmpty {
                    playerBreakdownCard
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
    }

    private var addSightingButton: some View {
        Button {
            showingAddSighting = true
        } label: {
            Label("Add Sighting", systemImage: "plus.circle.fill")
                .font(.title3)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
    }

    private var liveTrackingButton: some View {
        Button {
            showLiveTracking = true
        } label: {
            Label("Live Tracking", systemImage: "antenna.radiowaves.left.and.right")
                .font(.title3)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
    }

    private var totalCountCard: some View {
        VStack(spacing: 8) {
            let countOutline = topTeamColors.first?.opacity(0.5) ?? .black.opacity(0.15)
            Text("\(event.totalCount)")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: countOutline, radius: 2, x: 1, y: 1)

            Text("Total Jerseys Seen")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.85))

            Text(event.title)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))

            if let venue = event.venue {
                if event.watchLocation == .tv {
                    Label("Watching on TV · \(venue)", systemImage: "tv")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                } else {
                    Button {
                        openInMaps(venue: venue)
                    } label: {
                        Label(venue, systemImage: "mappin")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
            }

            if let url = event.gameUrl, let link = URL(string: url) {
                Link(destination: link) {
                    Label("Match Stats", systemImage: "safari")
                        .font(.caption)
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

    private var teamBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Team")
                .font(.headline)

            ForEach(event.teamBreakdown, id: \.team.id) { team, count in
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
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)

                    if isExpanded {
                        let players = event.players(for: team)
                        if players.isEmpty {
                            Text("No names recorded")
                                .font(.caption)
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
                                            .font(.subheadline)

                                        if count > 1 {
                                            Text("\(count)x")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        Button {
                                            EventActionHandler.incrementPlayer(team: team, name: name, event: event, context: context, lastIncrementTimes: &lastIncrementTimes)
                                        } label: {
                                            Image(systemName: "plus.circle")
                                                .font(.title3)
                                                .foregroundStyle(team.primaryColor)
                                        }
                                        .buttonStyle(.plain)
                                        .disabled(EventActionHandler.disabledForDebounce(team: team, name: name, lastIncrementTimes: lastIncrementTimes))
                                    }
                                    .padding(.leading, 20)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            EventActionHandler.deletePlayer(team: team, name: name, event: event, context: context)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                if team != event.teamBreakdown.last?.team {
                    Divider()
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    @ViewBuilder
    private var playerBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("By Player")
                .font(.headline)

            ForEach(event.playerBreakdown, id: \.playerName) { team, name, count in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(team.primaryColor)
                        .frame(width: 4)
                        .clipShape(RoundedRectangle(cornerRadius: 2))

                    HStack {
                        Text(team.abbreviation)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(name)
                            .font(.subheadline)

                        Spacer()

                        Text("\(count)")
                            .font(.subheadline)
                            .fontWeight(.bold)
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
                    .font(.headline)

                LazyVGrid(columns: [.init(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                    ForEach(sightingsWithPhotos, id: \.persistentModelID) { sighting in
                        VStack(spacing: 4) {
                            if let data = sighting.photoData, let image = UIImage(data: data) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            Text(sighting.displayName)
                                .font(.caption2)
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
        let query = "\(lat),\(lon)"
        let label = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        guard let url = URL(string: "maps://?ll=\(query)&q=\(label)") else { return }
        UIApplication.shared.open(url)
    }

    private var shareButton: some View {
        let summary = ExportService.generateSummary(for: event)
        return ShareLink(item: summary) {
            Label("Share Summary", systemImage: "square.and.arrow.up")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
    }
}
