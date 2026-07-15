import SwiftUI

struct StoreErrorView: View {
    let state: StoreState
    @State private var showResetConfirmation = false

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
        }
        .alert("Reset All Data?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { resetStore() }
        } message: {
            Text("All events, sightings, and teams will be permanently deleted. A fresh database will be created on next launch. This cannot be undone.")
        }
    }

    private func resetStore() {
        if let url = state.storeURL {
            try? FileManager.default.removeItem(at: url)
        }
        fatalError("User requested store reset — app will restart with fresh database")
    }
}
