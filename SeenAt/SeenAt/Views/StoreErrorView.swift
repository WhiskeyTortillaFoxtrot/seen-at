import SwiftUI

struct StoreErrorView: View {
    let state: StoreState
    @State private var showResetConfirmation = false
    @State private var resetComplete = false

    var body: some View {
        ZStack {
            if let image = StadiumPhotoService.image(for: "splash-screen-field") {
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }

            if resetComplete {
                resetSuccessView
            } else {
                errorView
            }
        }
    }

    @ViewBuilder
    private var errorView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)

            Text("Something Went Wrong")
                .font(.urbanist(.title, weight: .bold))
                .foregroundStyle(.white)

            Text(message)
                .font(.urbanist(.body))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let error = state.error {
                Text(error.localizedDescription)
                    .font(.urbanist(.caption))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            if allowsReset {
                Button(role: .destructive) {
                    showResetConfirmation = true
                } label: {
                    Text("Reset All Data")
                        .font(.urbanist(.headline))
                        .frame(maxWidth: 280, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .padding(.bottom, 48)
            } else {
                Text("Close and reopen the app to retry.")
                    .font(.urbanist(.headline))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.bottom, 48)
            }
        }
        .alert("Reset All Data?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { Task { await resetStore() } }
        } message: {
            Text("All events, sightings, and teams will be permanently deleted. A fresh database will be created on next launch. This cannot be undone.")
        }
    }

    private var message: String {
        switch state.failureReason {
        case .migrationFinalization:
            "Your data opened successfully, but migration safety cleanup could not be completed. The app is blocked from writing to protect your data."
        case .restoredMigrationFinalization:
            "A migration backup was restored and reopened, but safety cleanup could not be completed. Your restored data is preserved."
        case .recoveryRequired:
            "Migration recovery could not be completed safely. Your data has been preserved. Close and reopen the app after addressing the recovery state."
        case .restoreFailed:
            state.recoveryCompleted
                ? "A migration backup was restored. Please close and reopen the app to try again."
                : "Your data could not be loaded. It has been preserved on your device."
        case .storeLoad:
            "Your data could not be loaded. It has been preserved on your device."
        }
    }

    private var allowsReset: Bool {
        switch state.failureReason {
        case .migrationFinalization, .restoredMigrationFinalization, .recoveryRequired:
            false
        case .restoreFailed:
            !state.recoveryCompleted
        case .storeLoad:
            true
        }
    }

    @ViewBuilder
    private var resetSuccessView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)

            Text("Reset Complete")
                .font(.urbanist(.title, weight: .bold))
                .foregroundStyle(.white)

            Text("Your data has been reset. Please close and reopen the app to start fresh.")
                .font(.urbanist(.body))
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
    }

    private func resetStore() async {
        guard let url = state.storeURL else { return }
        do {
            try StoreBackupService.resetStoreData(
                storeURL: url,
                applicationSupportURL: StoreBackupService.applicationSupportURL(for: url)
            )
        } catch {
            state.error = error
            return
        }

        UserDefaults.standard.removeObject(forKey: "hasSeededTeams")
        UserDefaults.standard.removeObject(forKey: "seedVersion")

        await LiveActivityManager.endAll()
        PhotoCacheService.clear()

        resetComplete = true
    }
}
