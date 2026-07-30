import SwiftUI

struct SplashView: View {
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

            Text("Seen At")
                .font(.urbanist(size: titleSize, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}