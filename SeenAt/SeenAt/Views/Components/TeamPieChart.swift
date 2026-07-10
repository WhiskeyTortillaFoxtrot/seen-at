import SwiftUI
import Charts

struct TeamPieChart: View {
    let breakdown: [(team: Team, count: Int)]

    @State private var selectedAngle: Double?

    private var total: Int {
        breakdown.map(\.count).reduce(0, +)
    }

    private var coloredBreakdown: [(team: Team, count: Int, color: Color)] {
        var result: [(team: Team, count: Int, color: Color)] = []
        for (index, item) in breakdown.enumerated() {
            let primary = item.team.primaryColor
            if index > 0 {
                let prev = result[index - 1]
                if isClose(prev.color, primary) {
                    if item.count < prev.count {
                        result.append((item.team, item.count, item.team.secondaryColor))
                    } else {
                        result[index - 1] = (prev.team, prev.count, prev.team.secondaryColor)
                        result.append((item.team, item.count, primary))
                    }
                } else {
                    result.append((item.team, item.count, primary))
                }
            } else {
                result.append((item.team, item.count, primary))
            }
        }
        return result
    }

    private func isClose(_ a: Color, _ b: Color) -> Bool {
        let uiA = UIColor(a)
        let uiB = UIColor(b)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        uiA.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        uiB.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let dr = r1 - r2, dg = g1 - g2, db = b1 - b2
        return (dr * dr + dg * dg + db * db) < 0.15
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
            Chart(coloredBreakdown, id: \.team.id) { item in
                SectorMark(
                    angle: .value("Count", item.count),
                    innerRadius: .ratio(0.5),
                    angularInset: 2
                )
                .foregroundStyle(item.color)
                .opacity(selectedTeam == nil || selectedTeam?.id == item.team.id ? 1 : 0.4)
                .annotation(position: .overlay) {
                    VStack(spacing: 0) {
                        Text(item.team.abbreviation)
                            .font(.caption2.weight(.semibold))
                        Text("\(item.count)")
                            .font(.caption2)
                    }
                    .foregroundStyle(.white)
                }
            }
            .frame(height: 220)
            .chartAngleSelection(value: $selectedAngle)

            if let team = selectedTeam {
                let item = coloredBreakdown.first { $0.team.id == team.id }
                let count = item?.count ?? 0
                let color = item?.color ?? team.primaryColor
                let pct = total > 0 ? Int(Double(count) / Double(total) * 100) : 0
                HStack(spacing: 6) {
                    Circle()
                        .fill(color)
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
