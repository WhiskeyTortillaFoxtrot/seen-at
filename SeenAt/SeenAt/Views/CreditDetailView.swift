import SwiftUI

struct CreditDetailView: View {
    let entry: CreditEntry

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let image = VenueImageService.image(for: entry.identifier) {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(.horizontal)
                    } else {
                        Color(.systemGray5)
                            .aspectRatio(16 / 9, contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.urbanist(.largeTitle))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                    }

                    Text(entry.title)
                        .font(.urbanist(.title2, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)

                    if !entry.body.isEmpty {
                        if let attributed = try? AttributedString(markdown: entry.body) {
                            Text(attributed)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Photo Credit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
