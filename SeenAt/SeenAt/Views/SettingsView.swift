import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \Team.name) private var allTeams: [Team]

    @AppStorage("favoriteTeams") private var favoriteTeamsString: String = ""
    @AppStorage("defaultSport") private var defaultSport: String = "mlb"

    @State private var showingExporter = false
    @State private var exportCSV: String = ""
    @State private var showingDeleteSightingsAlert = false
    @State private var showingResetAlert = false

    var body: some View {
        Form {
            Section("Preferences") {
                Picker("Default Sport", selection: $defaultSport) {
                    Text("MLB").tag("mlb")
                    Text("NBA").tag("nba")
                    Text("NFL").tag("nfl")
                    Text("NHL").tag("nhl")
                    Text("LOVB").tag("lovb")
                    Text("MLS").tag("mls")
                }
                .pickerStyle(.menu)

                NavigationLink("Favorite Teams") {
                    FavoriteTeamsView()
                }
            }

            Section("Export") {
                Button("Export All Data as CSV") {
                    exportCSV = ExportService.generateAllDataCSV(context: context)
                    showingExporter = true
                }
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: CSVDocument(text: exportCSV),
                contentType: .commaSeparatedText,
                defaultFilename: "SeenAt-Export"
            ) { _ in }

            Section("Data") {
                Button("Delete All Sightings", role: .destructive) {
                    showingDeleteSightingsAlert = true
                }
                Button("Reset All Data", role: .destructive) {
                    showingResetAlert = true
                }
            }
            .confirmationDialog("Delete All Sightings?", isPresented: $showingDeleteSightingsAlert) {
                Button("Delete", role: .destructive) { deleteAllSightings() }
            } message: {
                Text("This will remove all jersey sightings from all events. Events will be preserved.")
            }
            .confirmationDialog("Reset All Data?", isPresented: $showingResetAlert) {
                Button("Reset", role: .destructive) { resetAllData() }
            } message: {
                Text("This will delete all events and sightings. This action cannot be undone.")
            }

            Section("About") {
                NavigationLink("Photo Credits") {
                    PhotoCreditsView()
                }

                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
    }

    private func deleteAllSightings() {
        let descriptor = FetchDescriptor<JerseySighting>()
        let sightings = (try? context.fetch(descriptor)) ?? []
        for s in sightings { context.delete(s) }
        try? context.save()
    }

    private func resetAllData() {
        let events = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        let sightings = (try? context.fetch(FetchDescriptor<JerseySighting>())) ?? []
        for e in events { context.delete(e) }
        for s in sightings { context.delete(s) }
        try? context.save()
    }
}

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else { throw CocoaError(.fileReadCorruptFile) }
        text = string
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        .init(regularFileWithContents: Data(text.utf8))
    }
}
