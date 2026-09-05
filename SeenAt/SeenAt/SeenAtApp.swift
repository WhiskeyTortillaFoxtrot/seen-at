import SwiftUI
import SwiftData
import Observation

enum StoreFailureReason: Sendable {
    case storeLoad
    case restoreFailed
    case migrationFinalization
    case restoredMigrationFinalization
    case recoveryRequired
    case corruptedRecovery
}

private enum DeepLinkError: Identifiable {
    case malformedURL
    case eventNotFound

    var id: Self { self }

    var message: String {
        switch self {
        case .malformedURL: return "The link could not be opened. It may be malformed."
        case .eventNotFound: return "The game for this link could not be found."
        }
    }
}

@MainActor
@main
struct SeenAtApp: App {
    @State private var container: ModelContainer?
    @State private var isLaunching = true
    @State private var launchInFlight = false

    @AppStorage(AppPreferences.hasSeenOnboardingKey) private var hasSeenOnboarding = false

    @State private var deepLinkDestination: DeepLinkDestination?
    @State private var deepLinkError: DeepLinkError?
    @State private var splashState = SplashState()
    @State private var storeState = StoreState()
    @Environment(\.scenePhase) private var scenePhase

    /// Launch is async: backup inspection, copying, validation, and hashing run on
    /// detached background tasks inside `StoreLauncher.launchAsync`, while
    /// `ModelContainer` creation (a SwiftData main-actor requirement) and all
    /// `StoreState` mutation stay on the main actor. The splash screen stays up
    /// with coarse progress until the container is ready or launch fails.
    init() {
        #if DEBUG
        // DEBUG-only reset path stays synchronous: it only deletes files and the
        // screenshot harness depends on it completing before first render.
        if ProcessInfo.processInfo.arguments.contains("--resetData") {
            let storeURL = StoreBackupService.defaultStoreURL()
            do {
                try StoreBackupService.resetStoreData(
                    storeURL: storeURL,
                    applicationSupportURL: StoreBackupService.applicationSupportURL(for: storeURL)
                )
                AppPreferences.resetForFreshStore()
                UserDefaults.standard.set(
                    "Chicago Cubs,Los Angeles Dodgers,St. Louis Cardinals",
                    forKey: AppPreferences.favoriteTeamsKey
                )
                UserDefaults.standard.set(true, forKey: AppPreferences.hasSeenOnboardingKey)
            } catch {
                let state = StoreState()
                state.error = error
                state.storeURL = StoreBackupService.defaultStoreURL()
                state.failureReason = .storeLoad
                _storeState = State(initialValue: state)
                _isLaunching = State(initialValue: false)
                return
            }
        }
        #endif
    }

    private func launch() async {
        guard container == nil, !launchInFlight else { return }
        launchInFlight = true
        defer {
            launchInFlight = false
            isLaunching = false
        }
        isLaunching = true

        let result = await StoreLauncher.launchAsync(
            containerFactory: { config in
                try ModelContainer(
                    for: Team.self, Event.self, JerseySighting.self,
                    migrationPlan: SeenAtMigrationPlan.self,
                    configurations: config
                )
            },
            onPhase: { phase in splashState.phase = phase }
        )
        container = result.container
        storeState = result.storeState

        guard let c = result.container else { return }
        await StoreLauncher.seedIfNeeded(in: c)
        splashState.isVisible = false
        splashState.phase = nil
        await StoreLauncher.startLiveActivities(for: c)
    }

    private func retryLaunch() {
        Task { await launch() }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    ZStack {
                        ContentView(
                            deepLinkDestination: $deepLinkDestination,
                            onDeepLinkError: { deepLinkError = .eventNotFound }
                        )

                        if splashState.isVisible {
                            SplashView(phase: splashState.phase)
                                .transition(.opacity)
                        }

                        if !hasSeenOnboarding, !splashState.isVisible {
                            OnboardingView()
                                .transition(.opacity)
                        }
                    }
                    .animation(.easeOut(duration: 0.5), value: splashState.isVisible)
                    .preferredColorScheme(.dark)
                    .onOpenURL { url in
                        switch DeepLinkParser.parse(url) {
                        case .success(let destination):
                            deepLinkDestination = destination
                        case .failure:
                            deepLinkError = .malformedURL
                        }
                    }
                    .alert(item: Binding(
                        get: { splashState.isVisible ? nil : deepLinkError },
                        set: { deepLinkError = $0; if $0 == nil { deepLinkDestination = nil } }
                    )) { error in
                        Alert(
                            title: Text("Couldn’t Open Link"),
                            message: Text(error.message),
                            dismissButton: .default(Text("OK"))
                        )
                    }
                    .modelContainer(container)
                    .onChange(of: scenePhase) { _, newPhase in
                        switch newPhase {
                        case .active:
                            DiagnosticsService.shared.appDidBecomeActive()
                            DiagnosticsService.shared.log(category: "App", level: .info, message: "App became active")
                        case .background:
                            DiagnosticsService.shared.appDidBackground()
                            DiagnosticsService.shared.log(category: "App", level: .info, message: "App entered background")
                        case .inactive:
                            break
                        @unknown default:
                            break
                        }
                    }
                } else if isLaunching {
                    SplashView(phase: splashState.phase)
                } else {
                    StoreErrorView(state: storeState, onRetry: { retryLaunch() })
                }
            }
            .task {
                await launch()
            }
        }
    }
}

@MainActor
@Observable
final class SplashState {
    var isVisible = true
    var phase: LaunchPhase?
}

@MainActor
@Observable
final class StoreState {
    var error: Error?
    var storeURL: URL?
    var failureReason: StoreFailureReason = .storeLoad
}
