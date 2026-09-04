import SwiftUI

struct SplashView: View {
    var phase: LaunchPhase?

    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 56

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

            VStack(spacing: 16) {
                Text("Seen At")
                    .font(.urbanist(size: titleSize, weight: .bold))
                    .foregroundStyle(.white)

                if let phase {
                    ProgressView()
                        .tint(.white)
                    Text(phase.displayName)
                        .font(.urbanist(.subheadline))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
    }
}
