import SwiftUI
import Charts

struct StatsWatchLocationCard: View {
    let stadiumCount: Int
    let tvCount: Int

    private var total: Int { stadiumCount + tvCount }

    private var stadiumPct: Int {
        total > 0 ? Int(Double(stadiumCount) / Double(total) * 100) : 0
    }

    private var tvPct: Int {
        total > 0 ? Int(Double(tvCount) / Double(total) * 100) : 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stadium vs TV")
                .font(.urbanist(.headline))

            if total == 0 {
                Text("No watch location data")
                    .font(.urbanist(.subheadline))
                    .foregroundStyle(.secondary)
            } else {
                Chart {
                    SectorMark(
                        angle: .value("Stadium", stadiumCount),
                        innerRadius: .ratio(0.5),
                        angularInset: 2
                    )
                    .foregroundStyle(Color.accentColor)
                    .annotation(position: .overlay) {
                        VStack(spacing: 0) {
                            Text("\(stadiumCount)")
                                .font(.urbanist(.caption2, weight: .bold))
                            Text("Stadium")
                                .font(.urbanist(.caption2))
                        }
                        .foregroundStyle(.white)
                    }

                    SectorMark(
                        angle: .value("TV", tvCount),
                        innerRadius: .ratio(0.5),
                        angularInset: 2
                    )
                    .foregroundStyle(Color.orange)
                    .annotation(position: .overlay) {
                        VStack(spacing: 0) {
                            Text("\(tvCount)")
                                .font(.urbanist(.caption2, weight: .bold))
                            Text("TV")
                                .font(.urbanist(.caption2))
                        }
                        .foregroundStyle(.white)
                    }
                }
                .frame(height: 160)

                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Stadium")
                            .font(.urbanist(.caption))
                            .foregroundStyle(.secondary)
                        Text("\(stadiumCount) (\(stadiumPct)%)")
                            .font(.urbanist(.headline, weight: .bold))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TV")
                            .font(.urbanist(.caption))
                            .foregroundStyle(.secondary)
                        Text("\(tvCount) (\(tvPct)%)")
                            .font(.urbanist(.headline, weight: .bold))
                    }
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}
