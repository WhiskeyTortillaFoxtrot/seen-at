import SwiftUI

struct SplashView: View {
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
                .font(.urbanist(size: 56, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}