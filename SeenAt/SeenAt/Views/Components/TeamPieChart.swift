import SwiftUI
import Charts

struct TeamPieChart: View {
    let breakdown: [(team: Team, count: Int)]

    @State private var selectedAngle: Double?

    private var total: Int {
        breakdown.map(\.count).reduce(0, +)
    }

    private var selectedTeam: Team? {
        guard let angle = selectedAngle else { return nil }
        let totalD = Double(total)
        guard totalD > 0 else { return nil }

        let tapDegrees = angle * 180 / .pi
        let normalized = ((tapDegrees.truncatingRemainder(dividingBy: 360)) + 360)
            .truncatingRemainder(dividingBy: 360)
        let fromNoon = (normalized + 90).truncatingRemainder(dividingBy: 360)

        var cumulative: Double = 0
        for (team, count) in breakdown {
            let proportion = Double(count) / totalD
            let endAngle = cumulative + proportion * 360
            if fromNoon >= cumulative && fromNoon < endAngle {
                return team
            }
            cumulative = endAngle
        }
        return nil
    }

    var body: some View {
        VStack(spacing: 8) {
            Chart(breakdown, id: \.team.id) { team, count in
                SectorMark(
                    angle: .value("Count", count),
                    innerRadius: .ratio(0.5),
                    angularInset: 2
                )
                .foregroundStyle(team.primaryColor)
                .opacity(selectedTeam == nil || selectedTeam?.id == team.id ? 1 : 0.4)
                .annotation(position: .overlay) {
                    VStack(spacing: 0) {
                        Text(team.abbreviation)
                            .font(.caption2.weight(.semibold))
                        Text("\(count)")
                            .font(.caption2)
                    }
                    .foregroundStyle(.white)
                }
            }
            .frame(height: 220)
            .chartAngleSelection(value: $selectedAngle)

            if let team = selectedTeam {
                let count = breakdown.first { $0.team.id == team.id }?.count ?? 0
                let pct = total > 0 ? Int(Double(count) / Double(total) * 100) : 0
                HStack(spacing: 6) {
                    Circle()
                        .fill(team.primaryColor)
                        .frame(width: 10, height: 10)
                    Text(team.name)
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text("\(count) (\(pct)%)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
                .transition(.opacity.animation(.snappy))
            }
        }
    }
}
