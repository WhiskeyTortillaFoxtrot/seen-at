import SwiftUI

struct PhotoCreditsView: View {
    @State private var content: String = ""

    var body: some View {
        ScrollView {
            if let attributed = try? AttributedString(markdown: content) {
                Text(attributed)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
        }
        .navigationTitle("Photo Credits")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard let url = Bundle.main.url(forResource: "PhotoCredits", withExtension: "md", subdirectory: "StadiumPhotos"),
                  let text = try? String(contentsOf: url)
            else { return }
            content = text
        }
    }
}
