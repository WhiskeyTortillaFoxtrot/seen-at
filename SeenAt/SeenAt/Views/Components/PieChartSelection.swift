import Foundation
import SwiftData

enum PieChartSelection {
    static func team(at angle: Double, in breakdown: [(team: Team, count: Int)]) -> Team? {
        let totalD = Double(breakdown.map(\.count).reduce(0, +))
        guard totalD > 0 else { return nil }

        let tapDegrees = angle * 180 / .pi
        let normalized = ((tapDegrees.truncatingRemainder(dividingBy: 360)) + 360)
            .truncatingRemainder(dividingBy: 360)
        let fromNoon = (normalized + 90).truncatingRemainder(dividingBy: 360)

        var bestTeam: Team? = breakdown.first?.team
        var bestDistance = Double.infinity
        var cumulative: Double = 0
        for (team, count) in breakdown {
            let proportion = Double(count) / totalD
            let center = cumulative + proportion * 180
            let distance = abs(fromNoon - center)
            if distance < bestDistance {
                bestDistance = distance
                bestTeam = team
            }
            cumulative += proportion * 360
        }
        return bestTeam
    }
}
