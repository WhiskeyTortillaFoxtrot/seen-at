import SwiftUI

struct CreditEntry: Identifiable {
    let id = UUID()
    let identifier: String
    let creditText: String

    var title: String {
        guard let start = creditText.firstRange(of: "**"),
              let end = creditText[start.upperBound...].firstRange(of: "**")
        else { return "" }
        return String(creditText[start.upperBound..<end.lowerBound])
    }

    var body: String {
        guard let start = creditText.firstRange(of: "**"),
              let end = creditText[start.upperBound...].firstRange(of: "**")
        else { return creditText }
        return String(creditText[end.upperBound...]).trimmingCharacters(in: .whitespaces)
    }
}

struct CreditSection: Identifiable {
    let id: String
    let letter: String
    let items: [CreditEntry]
}

struct PhotoCreditsView: View {
    @State private var sections: [CreditSection] = []
    @State private var selectedEntry: CreditEntry?

    var body: some View {
        List(sections) { section in
            Section(section.letter) {
                ForEach(section.items) { entry in
                    Button {
                        selectedEntry = entry
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            thumbnail(for: entry.identifier)
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 6))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.title)
                                    .font(.urbanist(.headline, weight: .bold))
                                if !entry.body.isEmpty {
                                    if let attributed = try? AttributedString(markdown: entry.body) {
                                        Text(attributed)
                                            .font(.urbanist(.caption))
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
        .navigationTitle("Photo Credits")
        .sheet(item: $selectedEntry) { entry in
            CreditDetailView(entry: entry)
        }
        .task { loadCredits() }
    }

    @ViewBuilder
    private func thumbnail(for identifier: String) -> some View {
        if let image = VenueImageService.image(for: identifier) {
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Color(.systemGray5)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
        }
    }

    private func loadCredits() {
        guard let url = Bundle.main.url(forResource: "PhotoCredits", withExtension: "md"),
              let text = try? String(contentsOf: url)
        else { return }

        var currentLetter: String?
        var temp: [String: [CreditEntry]] = [:]

        let lines = text.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if trimmed.hasPrefix("## ") {
                currentLetter = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                continue
            }

            guard let letter = currentLetter else { continue }

            let commaIdx = trimmed.firstIndex(of: ",")
            let identifier = commaIdx.map { trimmed[..<$0].trimmingCharacters(in: .whitespaces) } ?? ""
            let creditText = commaIdx.map { trimmed[trimmed.index(after: $0)...].trimmingCharacters(in: .whitespaces) } ?? trimmed

            guard !identifier.isEmpty else { continue }

            let entry = CreditEntry(identifier: identifier, creditText: creditText)
            temp[letter, default: []].append(entry)
        }

        let order = (65...90).map { String(UnicodeScalar($0)) } + ["Other"]
        sections = order.compactMap { letter in
            guard let items = temp[letter], !items.isEmpty else { return nil }
            return CreditSection(id: letter, letter: letter, items: items)
        }
    }
}
