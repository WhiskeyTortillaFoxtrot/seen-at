import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \Team.name) private var allTeams: [Team]

    @AppStorage(AppPreferences.favoriteTeamsKey) private var favoriteTeamsString: String = ""
    @AppStorage(AppPreferences.defaultSportKey) private var defaultSport: String = "mlb"
    @AppStorage(AppPreferences.hasSeenOnboardingKey) private var hasSeenOnboarding = false

    @State private var showingExporter = false
    @State private var exportCSV: String = ""
    @State private var showingDeleteSightingsAlert = false
    @State private var showingResetAlert = false
    @State private var showingDeleteError = false
    @State private var showingResetError = false
    @State private var showingDiagnosticsShareSheet = false
    @State private var diagnosticsExportURL: URL?
    @State private var showingDiagnosticsExportError = false

    var body: some View {
        Form {
            Section("Preferences") {
                Picker("Default Sport", selection: $defaultSport) {
                    Text("MLB").tag("mlb")
                    Text("NBA").tag("nba")
                    Text("WNBA").tag("wnba")
                    Text("NFL").tag("nfl")
                    Text("NHL").tag("nhl")
                    Text("LOVB").tag("lovb")
                    Text("MLS").tag("mls")
                    Text("NWSL").tag("nwsl")
                }
                .pickerStyle(.menu)

                NavigationLink("Favorite Teams") {
                    FavoriteTeamsView()
                }
            }
            .listRowBackground(GlassListRowBackground())

            Section("Export") {
                Button("Export All Data as CSV") {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    exportCSV = ExportService.generateAllDataCSV(context: context)
                    showingExporter = true
                }
                .accessibilityHint("Creates a CSV file with all your data")
            }
            .listRowBackground(GlassListRowBackground())
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
                .accessibilityHint("Removes all jersey sightings but keeps events")

                Button("Reset All Data", role: .destructive) {
                    showingResetAlert = true
                }
                .accessibilityHint("Deletes all events and sightings permanently")
            }
            .listRowBackground(GlassListRowBackground())
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
            .alert("Delete Failed", isPresented: $showingDeleteError) {
                Button("OK") { }
            } message: {
                Text("Could not delete all sightings. Please try again.")
            }
            .alert("Reset Failed", isPresented: $showingResetError) {
                Button("OK") { }
            } message: {
                Text("Could not reset data. Please try again.")
            }

            Section("Diagnostics") {
                Button {
                    shareDiagnostics()
                } label: {
                    Label("Share Diagnostics", systemImage: "square.and.arrow.up")
                }
                .accessibilityHint("Shares a diagnostics report for troubleshooting")
            }
            .listRowBackground(GlassListRowBackground())

            Section("About") {
                Button("Show Onboarding") {
                    hasSeenOnboarding = false
                }

                NavigationLink("Photo Credits") {
                    PhotoCreditsView()
                }

                NavigationLink("Credits") {
                    CreditsView()
                }

                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }
            }
            .listRowBackground(GlassListRowBackground())
        }
        .navigationTitle("Settings")
        .scrollContentBackground(.hidden)
        .toolbarBackground(.hidden, for: .navigationBar)
        .background { StadiumBackdrop(usesDailyImage: true) }
        .sheet(isPresented: $showingDiagnosticsShareSheet) {
            if let diagnosticsExportURL {
                ActivityViewController(items: [diagnosticsExportURL])
            }
        }
        .alert("Diagnostics Export Failed", isPresented: $showingDiagnosticsExportError) {
            Button("OK") {}
        } message: {
            Text("Could not create the diagnostics file. Please try again.")
        }
    }

    private func deleteAllSightings() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        if !SettingsService.deleteAllSightings(context: context) {
            showingDeleteError = true
        }
    }

    private func resetAllData() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        Task {
            if !(await SettingsService.resetAllData(context: context)) {
                showingResetError = true
            }
        }
    }

    private func shareDiagnostics() {
        do {
            diagnosticsExportURL = try DiagnosticsService.shared.exportURL(context: context)
            showingDiagnosticsShareSheet = true
        } catch {
            showingDiagnosticsExportError = true
        }
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
