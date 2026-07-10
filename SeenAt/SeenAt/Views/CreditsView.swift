import SwiftUI

struct CreditsView: View {
    var body: some View {
        List {
            Section("Font") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Urbanist")
                        .font(.urbanist(.headline, weight: .bold))
                    Text("Designed by Corey Hu")
                        .font(.urbanist(.subheadline))
                        .foregroundStyle(.secondary)
                    Text("Licensed under the SIL Open Font License 1.1")
                        .font(.urbanist(.caption))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)

                Link("View on Google Fonts", destination: URL(string: "https://fonts.google.com/specimen/Urbanist")!)
                    .font(.urbanist(.subheadline))

                Link("View on GitHub", destination: URL(string: "https://github.com/coreyhu/Urbanist")!)
                    .font(.urbanist(.subheadline))
            }

            Section("App") {
                HStack {
                    Text("SeenAt")
                        .font(.urbanist(.body))
                    Spacer()
                    Text("Track every jersey you've seen at the game")
                        .font(.urbanist(.caption))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .navigationTitle("Credits")
    }
}