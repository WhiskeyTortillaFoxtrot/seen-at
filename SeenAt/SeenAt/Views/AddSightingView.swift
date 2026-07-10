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
    @State private var photoMode: PhotoMode = .appStorage
    @State private var searchText: String = ""

    enum PhotoMode: String, CaseIterable {
        case appStorage = "In App"
        case photoLibrary = "Photos Library"
    }

    var body: some View {
        Form {
            Section("Team") {
                Picker("Select Team", selection: $selectedTeam) {
                    Text("Choose...").tag(nil as Team?)
                    ForEach(sortedTeams(allTeams, searchText: searchText, eventTitle: event.title, favoriteTeamNames: favoriteTeamNames)) { team in
                        HStack {
                            Circle()
                                .fill(team.primaryColor)
                                .frame(width: 12, height: 12)
                            Text(team.name)
                                .fontWeight(favoriteTeamNames.contains(team.name) ? .bold : .regular)
                        }
                        .tag(team as Team?)
                    }
                }
                .pickerStyle(.menu)
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
                    Picker("Photo Mode", selection: $photoMode) {
                        ForEach(PhotoMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if photoMode == .appStorage {
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
                    } else {
                        Label("Photo will be saved to your library", systemImage: "photo.on.rectangle.angled")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Button("Add Sighting") {
                addSighting()
            }
            .font(.headline)
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
                photoData = data
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
            photoData: photoMode == .appStorage ? photoData : nil,
            photoLocalIdentifier: photoMode == .photoLibrary ? UUID().uuidString : nil,
            event: event
        )
        context.insert(sighting)
        try? context.save()
        Task {
            await LiveActivityManager.startOrUpdate(for: event, teams: allTeams)
        }
        dismiss()
    }
}
