import SwiftUI
import SwiftData
import Charts

struct TeamPieChart: View {
    let breakdown: [(team: Team, count: Int)]

    @State private var selectedAngle: Double?
    @State private var selectedTeamId: PersistentIdentifier?

    private var total: Int {
        breakdown.map(\.count).reduce(0, +)
    }

    private func team(at angle: Double) -> Team? {
        PieChartSelection.team(at: angle, in: breakdown)
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

    var body: some View {
        VStack(spacing: 8) {
            Chart(coloredBreakdown, id: \.team.id) { item in
                SectorMark(
                    angle: .value("Count", item.count),
                    innerRadius: .ratio(0.5),
                    angularInset: 2
                )
                .foregroundStyle(item.color)
                .opacity(selectedTeamId == nil || selectedTeamId == item.team.id ? 1 : 0.4)
                .annotation(position: .overlay) {
                    VStack(spacing: 0) {
                        Text(item.team.abbreviation)
                            .font(.urbanist(.caption2, weight: .semibold))
                        Text("\(item.count)")
                            .font(.urbanist(.caption2))
                    }
                    .foregroundStyle(item.color.isLight ? .black : .white)
                }
            }
            .frame(height: 220)
            .chartAngleSelection(value: $selectedAngle)
            .onChange(of: selectedAngle) { _, newAngle in
                guard let angle = newAngle, let tapped = team(at: angle) else { return }
                selectedTeamId = tapped.id == selectedTeamId ? nil : tapped.id
            }

            if let teamId = selectedTeamId, let item = coloredBreakdown.first(where: { $0.team.id == teamId }) {
                let pct = total > 0 ? Int(Double(item.count) / Double(total) * 100) : 0
                HStack(spacing: 6) {
                    Circle()
                        .fill(item.color)
                        .frame(width: 10, height: 10)
                    Text(item.team.name)
                        .font(.urbanist(.subheadline, weight: .medium))
                    Spacer()
                    Text("\(item.count) (\(pct)%)")
                        .font(.urbanist(.subheadline))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
                .transition(.opacity.animation(.snappy))
            }
        }
    }
}
