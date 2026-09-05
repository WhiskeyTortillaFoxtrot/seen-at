import SwiftUI
import SwiftData
import PhotosUI
import OSLog

struct AddSightingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var event: Event
    @Query(sort: \Team.name) private var allTeams: [Team]
    @AppStorage(AppPreferences.favoriteTeamsKey) private var favoriteTeamsString: String = ""
    @AppStorage(AppPreferences.hapticsEnabledKey) private var hapticsEnabled = true

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
    @State private var showingSaveError = false
    @State private var saveErrorHaptic = 0
    @State private var didSaveSighting = false

    private var favoriteTeamNames: [String] {
        favoriteTeamsString.split(separator: ",").map(String.init).filter { !$0.isEmpty }
    }

    var body: some View {
        Form {
            Section("Team") {
                SightingTeamPicker(
                    homeTeamName: event.homeTeam,
                    awayTeamName: event.awayTeam,
                    allTeams: allTeams,
                    favoriteTeamNames: favoriteTeamNames,
                    selectedTeam: $selectedTeam,
                    selectedLeague: $selectedOtherLeague
                )
            }
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

            if event.watchLocation != .tv {
                Section("Photo (Optional)") {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        if let photoData, let image = UIImage(data: photoData) {
                            Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Label("Select Photo", systemImage: "photo")
                        }
                    }
                }
                .listRowBackground(GlassListRowBackground())
            }

            Button("Add Sighting") { addSighting() }
                .font(.urbanist(.headline))
                .frame(maxWidth: .infinity)
                .disabled(selectedTeam == nil || isPhotoLoading)
                .sensoryFeedback(.success, trigger: hapticsEnabled && didSaveSighting)
                .listRowBackground(GlassListRowBackground())
        }
        .navigationTitle("Add Sighting")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .background { StadiumBackdrop(usesDailyImage: true) }
        .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } } }
        .onChange(of: selectedPhotoItem) { _, item in loadPhoto(item) }
        .onDisappear(perform: cancelPhotoLoad)
        .alert("Save Failed", isPresented: $showingSaveError) { Button("OK") {} } message: {
            Text("Could not save the sighting. Please try again.")
        }
        .sensoryFeedback(.error, trigger: hapticsEnabled ? saveErrorHaptic : 0)
        .sheet(item: $selectedOtherLeague) { league in
            SightingLeaguePicker(league: league, allTeams: allTeams, favoriteTeamNames: favoriteTeamNames) { team in
                selectedTeam = team
                selectedOtherLeague = nil
            }
        }
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

    private func cancelPhotoLoad() {
        photoLoadGeneration += 1
        photoLoadTask?.cancel()
        photoLoadTask = nil
        isPhotoLoading = false
    }

    private nonisolated static func compressPhoto(_ data: Data) async -> Data? {
        PhotoCompression.compressPhoto(data)
    }

    private func addSighting() {
        guard let selectedTeam, !isPhotoLoading else { return }
        guard !EventPreviewPolicy.isReadOnly(event) else {
            dismiss()
            return
        }
        let trim: (String) -> String? = { value in
            let trimmed = value.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? nil : trimmed
        }
        let sighting = JerseySighting(team: selectedTeam, firstName: trim(playerFirstName), lastName: trim(playerLastName), playerNumber: trim(playerNumber), photoData: photoData, event: event)
        context.insert(sighting)
        guard context.saveAndLog("Failed to save sighting") else {
            context.delete(sighting)
            showingSaveError = true
            saveErrorHaptic += 1
            return
        }
        didSaveSighting.toggle()
        Task { await LiveActivityManager.updateIfActive(for: event, teams: allTeams) }
        dismiss()
    }
}
