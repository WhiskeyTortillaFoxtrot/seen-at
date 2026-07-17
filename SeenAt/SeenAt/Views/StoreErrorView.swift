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

            Text("Your data could not be loaded. It has been preserved on your device.")
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
        }
        .alert("Reset All Data?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { Task { await resetStore() } }
        } message: {
            Text("All events, sightings, and teams will be permanently deleted. A fresh database will be created on next launch. This cannot be undone.")
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

        let base = url.deletingPathExtension()
        let ext = url.pathExtension
        let sidecars = [
            base.appendingPathExtension("\(ext)-wal"),
            base.appendingPathExtension("\(ext)-shm"),
        ]
        for file in [url] + sidecars {
            try? FileManager.default.removeItem(at: file)
        }

        UserDefaults.standard.removeObject(forKey: "hasSeededTeams")
        UserDefaults.standard.removeObject(forKey: "seedVersion")

        await LiveActivityManager.endAll()
        PhotoCacheService.clear()

        resetComplete = true
    }
}
