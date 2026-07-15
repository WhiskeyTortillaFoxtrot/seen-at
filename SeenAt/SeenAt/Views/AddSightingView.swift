import SwiftUI
import SwiftData
import PhotosUI

struct AddSightingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Bindable var event: Event

    @Query(sort: \Team.name) private var allTeams: [Team]

    @AppStorage("favoriteTeams") private var favoriteTeamsString: String = ""
    private var favoriteTeamNames: [String] {
        favoriteTeamsString.split(separator: ",").map(String.init).filter { !$0.isEmpty }
    }

    @State private var selectedTeam: Team?
    @State private var playerFirstName: String = ""
    @State private var playerLastName: String = ""
    @State private var playerNumber: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var selectedOtherLeague: OtherLeague?
    @State private var showingSaveError = false

    private let allLeagues: [(id: String, label: String)] = [
        ("mlb", "MLB"), ("nba", "NBA"), ("nfl", "NFL"),
        ("nhl", "NHL"), ("lovb", "LOVB"), ("mls", "MLS"),
    ]

    private var eventGameTeams: [Team] {
        let names = [event.homeTeam, event.awayTeam].compactMap { $0 }
        let gameTeamOrder = names
        return allTeams
            .filter { names.contains($0.name) }
            .sorted { a, b in
                let aIdx = gameTeamOrder.firstIndex(of: a.name) ?? 0
                let bIdx = gameTeamOrder.firstIndex(of: b.name) ?? 0
                return aIdx < bIdx
            }
    }

    private var eventLeague: String? {
        eventGameTeams.first?.sport ?? eventGameTeams.last?.sport
    }

    private var eventLeagueNonGameTeams: [Team] {
        guard let league = eventLeague else { return [] }
        let gameTeamNames = Set(eventGameTeams.map { $0.name })
        let favoriteSet = Set(favoriteTeamNames)
        return allTeams
            .filter { $0.sport == league && !gameTeamNames.contains($0.name) }
            .sorted { a, b in
                let aFav = favoriteSet.contains(a.name)
                let bFav = favoriteSet.contains(b.name)
                if aFav && !bFav { return true }
                if !aFav && bFav { return false }
                return a.name < b.name
            }
    }

    private var otherLeagues: [OtherLeague] {
        allLeagues
            .filter { $0.id != eventLeague }
            .map { OtherLeague(id: $0.id, label: $0.label) }
    }

    var body: some View {
        Form {
            Section("Team") {
                teamMenu
            }

            Section("Player (Optional)") {
                HStack {
                    TextField("First", text: $playerFirstName)
                    TextField("Last", text: $playerLastName)
                }
                TextField("Number", text: $playerNumber)
                    .keyboardType(.numberPad)
            }

            if event.watchLocation != .tv {
                Section("Photo (Optional)") {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        if let photoData, let image = UIImage(data: photoData) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Label("Select Photo", systemImage: "photo")
                        }
                    }
                }
            }

            Button("Add Sighting") {
                addSighting()
            }
            .font(.urbanist(.headline))
            .frame(maxWidth: .infinity)
            .disabled(selectedTeam == nil)
        }
        .navigationTitle("Add Sighting")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
        }
        .onChange(of: selectedPhotoItem) { _, item in
            Task {
                guard let data = try? await item?.loadTransferable(type: Data.self) else { return }
                guard let image = UIImage(data: data) else { return }
                photoData = image.downsampled(maxDimension: 1200)
            }
        }
        .alert("Save Failed", isPresented: $showingSaveError) {
            Button("OK") { }
        } message: {
            Text("Could not save the sighting. Please try again.")
        }
        .sheet(item: $selectedOtherLeague) { league in
            OtherLeaguePicker(league: league, allTeams: allTeams, favoriteTeamNames: favoriteTeamNames) { team in
                selectedTeam = team
                selectedOtherLeague = nil
            }
        }
    }

    private var teamMenu: some View {
        Menu {
            Button("Choose...") { selectedTeam = nil }

            if !eventGameTeams.isEmpty {
                ForEach(eventGameTeams) { team in
                    teamButton(team)
                }
                Divider()
            }

            if let _ = eventLeague {
                ForEach(eventLeagueNonGameTeams) { team in
                    teamButton(team)
                }
                Divider()

                ForEach(otherLeagues) { league in
                    Button(league.label) {
                        selectedOtherLeague = league
                    }
                }
            } else {
                ForEach(sortedTeams(allTeams, searchText: "", awayTeam: event.awayTeam, homeTeam: event.homeTeam, favoriteTeamNames: favoriteTeamNames)) { team in
                    teamButton(team)
                }
            }
        } label: {
            HStack {
                Text("Select Team")
                Spacer()
                if let team = selectedTeam {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(team.primaryColor)
                            .frame(width: 12, height: 12)
                        Text(team.name)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Choose...")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func teamButton(_ team: Team) -> some View {
        Button {
            selectedTeam = team
        } label: {
            HStack {
                Circle()
                    .fill(team.primaryColor)
                    .frame(width: 12, height: 12)
                Text(team.name)
                if favoriteTeamNames.contains(team.name) {
                    Spacer()
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                }
            }
        }
    }

    private func addSighting() {
        guard let team = selectedTeam else { return }

        let sighting = JerseySighting(
            team: team,
            firstName: playerFirstName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : playerFirstName.trimmingCharacters(in: .whitespaces),
            lastName: playerLastName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : playerLastName.trimmingCharacters(in: .whitespaces),
            playerNumber: playerNumber.trimmingCharacters(in: .whitespaces).isEmpty ? nil : playerNumber.trimmingCharacters(in: .whitespaces),
            photoData: photoData,
            event: event
        )
        context.insert(sighting)
        guard context.saveAndLog("Failed to save sighting") else {
            context.delete(sighting)
            showingSaveError = true
            return
        }
        Task {
            await LiveActivityManager.startOrUpdate(for: event, teams: allTeams)
        }
        dismiss()
    }
}

private struct OtherLeague: Identifiable {
    let id: String
    let label: String
}

private struct OtherLeaguePicker: View {
    let league: OtherLeague
    let allTeams: [Team]
    let favoriteTeamNames: [String]
    let onSelect: (Team) -> Void

    @Environment(\.dismiss) private var dismiss

    private var leagueTeams: [Team] {
        let favoriteSet = Set(favoriteTeamNames)
        return allTeams
            .filter { $0.sport == league.id }
            .sorted { a, b in
                let aFav = favoriteSet.contains(a.name)
                let bFav = favoriteSet.contains(b.name)
                if aFav && !bFav { return true }
                if !aFav && bFav { return false }
                return a.name < b.name
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
                        Circle()
                            .fill(team.primaryColor)
                            .frame(width: 12, height: 12)
                        Text(team.name)
                            .font(favoriteTeamNames.contains(team.name) ? .urbanist(.body, weight: .bold) : .urbanist(.body))
                        if favoriteTeamNames.contains(team.name) {
                            Spacer()
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                                .font(.caption)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
            .navigationTitle(league.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}