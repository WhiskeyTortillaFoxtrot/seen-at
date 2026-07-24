import SwiftUI
import SwiftData
import Observation

enum StoreFailureReason {
    case storeLoad
    case restoreFailed
    case migrationFinalization
    case restoredMigrationFinalization
    case recoveryRequired
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
    let container: ModelContainer?

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    @State private var deepLinkEventID: UUID?
    @State private var deepLinkError: DeepLinkError?
    @State private var splashState = SplashState()
    @State private var storeState = StoreState()

    /// All backup/restore work runs synchronously on `@MainActor` because
    /// SwiftData's `ModelContainer` must be created on the main actor, and the
    /// backup must exist *before* container creation so the recovery path can
    /// restore it on failure.  If launch time becomes a concern, the escape
    /// hatch is pre-warming the backup on a background thread during a push
    /// notification handler or app extension.
    init() {
        let result = StoreLauncher.launch { config in
            try ModelContainer(
                for: Team.self, Event.self, JerseySighting.self,
                migrationPlan: SeenAtMigrationPlan.self,
                configurations: config
            )
        }
        container = result.container
        _storeState = State(wrappedValue: result.storeState)

        guard let c = container else {
            if result.storeState.recoveryCompleted {
                splashState.isVisible = false
            }
            return
        }
        let state = splashState
        Task {
            await StoreLauncher.seedIfNeeded(in: c)
            state.isVisible = false
            await StoreLauncher.startLiveActivities(for: c)
        }
    }

    var body: some Scene {
        WindowGroup {
            if let container {
                ZStack {
                    ContentView(deepLinkEventID: $deepLinkEventID, onDeepLinkError: { deepLinkError = .eventNotFound })

                    if splashState.isVisible {
                        SplashView()
                            .transition(.opacity)
                    }

                    if !hasSeenOnboarding, !splashState.isVisible {
                        OnboardingView()
                            .transition(.opacity)
                    }
                }
                .animation(.easeOut(duration: 0.5), value: splashState.isVisible)
                .onOpenURL { url in
                    switch DeepLinkParser.parse(url) {
                    case .success(let eventID):
                        deepLinkEventID = eventID
                    case .failure:
                        deepLinkError = .malformedURL
                    }
                }
                .alert(item: Binding(
                    get: { splashState.isVisible ? nil : deepLinkError },
                    set: { deepLinkError = $0; if $0 == nil { deepLinkEventID = nil } }
                )) { error in
                    Alert(
                        title: Text("Couldn’t Open Link"),
                        message: Text(error.message),
                        dismissButton: .default(Text("OK"))
                    )
                }
                .modelContainer(container)
            } else {
                StoreErrorView(state: storeState)
            }
        }
    }
}

@MainActor
@Observable
final class SplashState {
    var isVisible = true
}

@MainActor
@Observable
final class StoreState {
    var error: Error?
    var storeURL: URL?
    var recoveryCompleted = false
    var failureReason: StoreFailureReason = .storeLoad
}

