import SwiftUI
import SwiftData
import PhotosUI
import OSLog

struct SightingEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Bindable var sighting: JerseySighting
    let onSaved: () -> Void

    @Query(sort: \Team.name) private var allTeams: [Team]
    @AppStorage(AppPreferences.favoriteTeamsKey) private var favoriteTeamsString: String = ""

    @State private var selectedTeam: Team?
    @State private var playerFirstName = ""
    @State private var playerLastName = ""
    @State private var playerNumber = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var selectedOtherLeague: EditorOtherLeague?
    @State private var showingDeleteConfirmation = false
    @State private var showingSaveError = false
    @State private var didLoad = false

    private var event: Event? { sighting.event }
    private var favoriteTeamNames: [String] {
        favoriteTeamsString.split(separator: ",").map(String.init).filter { !$0.isEmpty }
    }
    private var eventGameTeams: [Team] {
        guard let event else { return [] }
        let names = [event.homeTeam, event.awayTeam].compactMap { $0 }
        return allTeams.filter { names.contains($0.name) }
            .sorted { (names.firstIndex(of: $0.name) ?? 0) < (names.firstIndex(of: $1.name) ?? 0) }
    }
    private var eventLeague: String? { eventGameTeams.first?.sport ?? eventGameTeams.last?.sport }
    private var eventLeagueNonGameTeams: [Team] {
        guard let eventLeague else { return [] }
        let gameTeamNames = Set(eventGameTeams.map(\.name))
        let favorites = Set(favoriteTeamNames)
        return allTeams.filter { $0.sport == eventLeague && !gameTeamNames.contains($0.name) }
            .sorted { lhs, rhs in
                let lhsFavorite = favorites.contains(lhs.name)
                let rhsFavorite = favorites.contains(rhs.name)
                if lhsFavorite != rhsFavorite { return lhsFavorite }
                return lhs.name < rhs.name
            }
    }
    private var otherLeagues: [EditorOtherLeague] {
        allLeagueOptions.filter { $0.id != eventLeague }.map(EditorOtherLeague.init)
    }
    private var canEditPhoto: Bool { event?.watchLocation != .tv }

    var body: some View {
        Form {
            Section("Team") { teamMenu }
                .listRowBackground(GlassListRowBackground())

            Section("Player (Optional)") {
                HStack {
                    TextField("First", text: $playerFirstName)
                        .onChange(of: playerFirstName) { _, value in playerFirstName = String(value.prefix(50)) }
                    TextField("Last", text: $playerLastName)
                        .onChange(of: playerLastName) { _, value in playerLastName = String(value.prefix(50)) }
                }
                TextField("Number", text: $playerNumber)
                    .keyboardType(.numberPad)
                    .onChange(of: playerNumber) { _, value in playerNumber = String(value.prefix(10)) }
            }
            .listRowBackground(GlassListRowBackground())

            if canEditPhoto {
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
                    if photoData != nil {
                        Button("Remove Photo", role: .destructive) { removePhoto() }
                    }
                }
                .listRowBackground(GlassListRowBackground())
            }

            Button("Save Changes") { save() }
                .font(.urbanist(.headline))
                .frame(maxWidth: .infinity)
                .disabled(selectedTeam == nil)
                .listRowBackground(GlassListRowBackground())

            Section {
                Button("Delete Sighting", role: .destructive) { showingDeleteConfirmation = true }
                    .frame(maxWidth: .infinity)
            }
            .listRowBackground(GlassListRowBackground())
        }
        .navigationTitle("Edit Sighting")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .background { StadiumBackdrop(venue: event?.venue, usesDailyImage: true) }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
        }
        .onAppear(perform: loadDraft)
        .onChange(of: selectedPhotoItem) { _, item in loadPhoto(item) }
        .sheet(item: $selectedOtherLeague) { league in
            EditorLeaguePicker(league: league, allTeams: allTeams, favoriteTeamNames: favoriteTeamNames) { team in
                selectedTeam = team
                selectedOtherLeague = nil
            }
        }
        .confirmationDialog("Delete this sighting?", isPresented: $showingDeleteConfirmation) {
            Button("Delete Sighting", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This only removes this one sighting and cannot be undone.")
        }
        .alert("Save Failed", isPresented: $showingSaveError) {
            Button("OK") {}
        } message: {
            Text("Could not save the sighting. Please try again.")
        }
    }

    private var teamMenu: some View {
        Menu {
            Button("Choose...") { selectedTeam = nil }
            if !eventGameTeams.isEmpty {
                ForEach(eventGameTeams) { team in teamButton(team) }
                Divider()
            }
            if let eventLeague {
                ForEach(eventLeagueNonGameTeams) { team in teamButton(team) }
                Divider()
                ForEach(otherLeagues) { league in
                    Button(league.label) { selectedOtherLeague = league }
                }
            } else {
                ForEach(allLeagueOptions.map(EditorOtherLeague.init)) { league in
                    Button(league.label) { selectedOtherLeague = league }
                }
            }
        } label: {
            HStack {
                Text("Select Team")
                Spacer()
                if let selectedTeam {
                    Circle().fill(selectedTeam.primaryColor).frame(width: 12, height: 12)
                    Text(selectedTeam.name).foregroundStyle(.secondary)
                } else {
                    Text("Choose...").foregroundStyle(.secondary)
                }
            }
        }
    }

    private func teamButton(_ team: Team) -> some View {
        Button { selectedTeam = team } label: {
            HStack {
                Circle().fill(team.primaryColor).frame(width: 12, height: 12)
                Text(team.name)
                if favoriteTeamNames.contains(team.name) { Image(systemName: "star.fill").foregroundStyle(.yellow) }
            }
        }
    }

    private func loadDraft() {
        guard !didLoad else { return }
        selectedTeam = sighting.team
        playerFirstName = sighting.firstName ?? ""
        playerLastName = sighting.lastName ?? ""
        playerNumber = sighting.playerNumber ?? ""
        photoData = sighting.photoData
        didLoad = true
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        Task(priority: .userInitiated) {
            do {
                guard let data = try await item?.loadTransferable(type: Data.self) else { return }
                let compressed = await Task.detached(priority: .userInitiated) {
                    data.downsampledImage(maxDimension: 1200)
                }.value
                photoData = compressed
            } catch {
                Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.seenat", category: "Photo")
                    .error("Failed to load/resize photo: \(error, privacy: .auto)")
            }
        }
    }

    private func removePhoto() {
        selectedPhotoItem = nil
        photoData = nil
    }

    private func save() {
        guard let selectedTeam else { return }
        let trim: (String) -> String? = { value in
            let trimmed = value.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : trimmed
        }
        guard SightingEditingService.update(
            sighting,
            team: selectedTeam,
            firstName: trim(playerFirstName),
            lastName: trim(playerLastName),
            playerNumber: trim(playerNumber),
            photoData: canEditPhoto ? photoData : sighting.photoData,
            context: context
        ) else {
            showingSaveError = true
            return
        }
        onSaved()
        dismiss()
    }

    private func delete() {
        guard SightingEditingService.delete(sighting, context: context) else {
            showingSaveError = true
            return
        }
        onSaved()
        dismiss()
    }
}

private let allLeagueOptions = [
    (id: "mlb", label: "MLB"), (id: "nba", label: "NBA"), (id: "nfl", label: "NFL"),
    (id: "nhl", label: "NHL"), (id: "lovb", label: "LOVB"), (id: "mls", label: "MLS"),
    (id: "nwsl", label: "NWSL"),
]

private struct EditorOtherLeague: Identifiable {
    let id: String
    let label: String
    init(id: String, label: String) { self.id = id; self.label = label }
    init(_ league: (id: String, label: String)) { self.init(id: league.id, label: league.label) }
}

private struct EditorLeaguePicker: View {
    let league: EditorOtherLeague
    let allTeams: [Team]
    let favoriteTeamNames: [String]
    let onSelect: (Team) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(allTeams.filter { $0.sport == league.id }.sorted { $0.name < $1.name }) { team in
                Button {
                    onSelect(team)
                    dismiss()
                } label: {
                    HStack {
                        Circle().fill(team.primaryColor).frame(width: 12, height: 12)
                        Text(team.name)
                        if favoriteTeamNames.contains(team.name) { Image(systemName: "star.fill").foregroundStyle(.yellow) }
                    }
                }
                .foregroundStyle(.primary)
            }
            .navigationTitle(league.label)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } } }
        }
    }
}
