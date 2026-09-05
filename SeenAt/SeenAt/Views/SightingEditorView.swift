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
    @State private var photoLoadTask: Task<Void, Never>?
    @State private var photoLoadGeneration = 0
    @State private var isPhotoLoading = false
    @State private var selectedOtherLeague: SightingLeague?
    @State private var showingDeleteConfirmation = false
    @State private var showingSaveError = false
    @State private var didLoad = false
    @State private var didDelete = false
    @State private var eventHomeTeam: String?
    @State private var eventAwayTeam: String?
    @State private var eventVenue: String?
    @State private var canEditPhoto = true

    private var favoriteTeamNames: [String] {
        favoriteTeamsString.split(separator: ",").map(String.init).filter { !$0.isEmpty }
    }

    var body: some View {
        Group {
            if didDelete {
                Color.clear
            } else {
                editorForm
            }
        }
        .navigationTitle("Edit Sighting")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .background { StadiumBackdrop(venue: eventVenue, usesDailyImage: true) }
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } } }
        .onAppear(perform: loadDraft)
        .onChange(of: selectedPhotoItem) { _, item in loadPhoto(item) }
        .onDisappear(perform: cancelPhotoLoad)
        .sheet(item: $selectedOtherLeague) { league in
            SightingLeaguePicker(league: league, allTeams: allTeams, favoriteTeamNames: favoriteTeamNames) { team in
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
        .alert("Save Failed", isPresented: $showingSaveError) { Button("OK") {} } message: {
            Text("Could not save the sighting. Please try again.")
        }
    }

    private var editorForm: some View {
        Form {
            Section("Team") {
                SightingTeamPicker(homeTeamName: eventHomeTeam, awayTeamName: eventAwayTeam, allTeams: allTeams, favoriteTeamNames: favoriteTeamNames, selectedTeam: $selectedTeam, selectedLeague: $selectedOtherLeague)
            }
            .listRowBackground(GlassListRowBackground())
            Section("Player (Optional)") {
                HStack {
                    TextField("First", text: $playerFirstName).onChange(of: playerFirstName) { _, value in playerFirstName = String(value.prefix(50)) }
                    TextField("Last", text: $playerLastName).onChange(of: playerLastName) { _, value in playerLastName = String(value.prefix(50)) }
                }
                TextField("Number", text: $playerNumber).keyboardType(.numberPad)
                    .onChange(of: playerNumber) { _, value in playerNumber = String(value.prefix(10)) }
            }
            .listRowBackground(GlassListRowBackground())
            if canEditPhoto {
                Section("Photo (Optional)") {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        if let photoData, let image = UIImage(data: photoData) {
                            Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Label("Select Photo", systemImage: "photo")
                        }
                    }
                    if photoData != nil { Button("Remove Photo", role: .destructive) { removePhoto() } }
                }
                .listRowBackground(GlassListRowBackground())
            }
            Button("Save Changes") { save() }.font(.urbanist(.headline)).frame(maxWidth: .infinity)
                .disabled(selectedTeam == nil || isPhotoLoading).listRowBackground(GlassListRowBackground())
            Section { Button("Delete Sighting", role: .destructive) { showingDeleteConfirmation = true }.frame(maxWidth: .infinity) }
                .listRowBackground(GlassListRowBackground())
        }
    }

    private func loadDraft() {
        guard !didLoad else { return }
        selectedTeam = sighting.team
        playerFirstName = sighting.firstName ?? ""
        playerLastName = sighting.lastName ?? ""
        playerNumber = sighting.playerNumber ?? ""
        photoData = sighting.photoData
        eventHomeTeam = sighting.event?.homeTeam
        eventAwayTeam = sighting.event?.awayTeam
        eventVenue = sighting.event?.venue
        canEditPhoto = sighting.event?.watchLocation != .tv
        didLoad = true
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        photoLoadTask?.cancel()
        photoLoadGeneration += 1
        let generation = photoLoadGeneration
        guard let item else {
            photoData = nil
            photoLoadTask = nil
            isPhotoLoading = false
            return
        }
        isPhotoLoading = true
        photoLoadTask = Task { @MainActor in
            defer {
                if photoLoadGeneration == generation {
                    photoLoadTask = nil
                    isPhotoLoading = false
                }
            }
            do {
                guard let data = try await item.loadTransferable(type: Data.self), !Task.isCancelled else { return }
                let compressed = await Self.compressPhoto(data)
                guard !Task.isCancelled, photoLoadGeneration == generation else { return }
                photoData = compressed
            } catch {
                guard !Task.isCancelled else { return }
                Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.seenat", category: "Photo")
                    .error("Failed to load/resize photo: \(error, privacy: .auto)")
            }
        }
    }

    private func removePhoto() {
        cancelPhotoLoad()
        selectedPhotoItem = nil
        photoData = nil
    }

    private func cancelPhotoLoad() {
        photoLoadGeneration += 1
        photoLoadTask?.cancel()
        photoLoadTask = nil
        isPhotoLoading = false
    }

    private nonisolated static func compressPhoto(_ data: Data) async -> Data? {
        PhotoCompression.compressPhoto(data)
    }

    private func save() {
        guard let selectedTeam, !isPhotoLoading else { return }
        let trim: (String) -> String? = { value in let trimmed = value.trimmingCharacters(in: .whitespaces); return trimmed.isEmpty ? nil : trimmed }
        guard SightingEditingService.update(sighting, team: selectedTeam, firstName: trim(playerFirstName), lastName: trim(playerLastName), playerNumber: trim(playerNumber), photoData: canEditPhoto ? photoData : sighting.photoData, context: context) else {
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
        didDelete = true
        onSaved()
        dismiss()
    }
}
