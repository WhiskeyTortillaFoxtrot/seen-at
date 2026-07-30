import SwiftUI

struct StatsVenueCard: View {
    let venues: [(venue: String, count: Int)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Most-Attended Venues")
                .font(.urbanist(.headline))

            if venues.isEmpty {
                Text("No venue data")
                    .font(.urbanist(.subheadline))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(venues.enumerated()), id: \.offset) { index, venue in
                    HStack(spacing: 8) {
                        Text("\(index + 1).")
                            .font(.urbanist(.subheadline))
                            .foregroundStyle(.secondary)
                            .frame(width: 24, alignment: .leading)

                        Text(venue.venue)
                            .font(.urbanist(.subheadline, weight: .medium))
                            .lineLimit(1)

                        Spacer()

                        Text("\(venue.count)")
                            .font(.urbanist(.subheadline, weight: .bold))
                            .foregroundStyle(.primary)

                        Text(venue.count == 1 ? "game" : "games")
                            .font(.urbanist(.caption))
                            .foregroundStyle(.secondary)
                    }

                    if venue.venue != venues.last?.venue {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}
