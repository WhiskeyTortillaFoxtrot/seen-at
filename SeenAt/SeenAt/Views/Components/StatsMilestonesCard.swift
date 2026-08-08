import SwiftUI

struct Milestone {
    let type: MilestoneType
    let threshold: Int
    let date: Date
    let countAtMilestone: Int
}

enum MilestoneType: String {
    case jerseys = "Jersey"
    case games = "Game"
}

let jerseyThresholds: [Int] = Array(stride(from: 50, through: 5000, by: 50))
let gameThresholds: [Int] = [10, 25, 50, 100, 250, 500, 1000]

func totalJerseys(for events: [Event]) -> Int {
    events.reduce(0) { $0 + $1.sightings.count }
}

func totalGames(for events: [Event]) -> Int {
    events.count
}

func nextJerseyMilestone(after count: Int) -> Int? {
    jerseyThresholds.first { $0 > count }
}

func nextGameMilestone(after count: Int) -> Int? {
    gameThresholds.first { $0 > count }
}

func achievedMilestones(for events: [Event]) -> [Milestone] {
    let sortedEvents = events.sorted { $0.date < $1.date }
    var milestones: [Milestone] = []

    var cumulativeJerseys = 0
    var cumulativeGames = 0

    for event in sortedEvents {
        cumulativeGames += 1
        cumulativeJerseys += event.sightings.count

        for threshold in gameThresholds where cumulativeGames == threshold {
            milestones.append(Milestone(
                type: .games,
                threshold: threshold,
                date: event.date,
                countAtMilestone: cumulativeGames
            ))
        }

        for threshold in jerseyThresholds where cumulativeJerseys >= threshold {
            let prevTotal = cumulativeJerseys - event.sightings.count
            if prevTotal < threshold && cumulativeJerseys >= threshold {
                milestones.append(Milestone(
                    type: .jerseys,
                    threshold: threshold,
                    date: event.date,
                    countAtMilestone: cumulativeJerseys
                ))
            }
        }
    }

    return milestones.sorted { $0.date < $1.date }
}

struct StatsMilestonesCard: View {
    let events: [Event]

    private var nextJerseyMilestoneThreshold: Int? {
        nextJerseyMilestone(after: totalJerseys(for: events))
    }

    private var nextGameMilestoneThreshold: Int? {
        nextGameMilestone(after: totalGames(for: events))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Milestones")
                .font(.urbanist(.headline))

            VStack(alignment: .leading, spacing: 16) {
                let jerseyCount = totalJerseys(for: events)
                if let next = nextJerseyMilestoneThreshold {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Next Jersey Milestone")
                            .font(.urbanist(.caption))
                            .foregroundStyle(.secondary)
                        Text("\(jerseyCount) / \(next)")
                            .font(.urbanist(.headline, weight: .bold))
                        ProgressView(value: Double(jerseyCount), total: Double(next))
                            .tint(Color.accentColor)
                    }
                }

                let gameCount = totalGames(for: events)
                if let next = nextGameMilestoneThreshold {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Next Game Milestone")
                            .font(.urbanist(.caption))
                            .foregroundStyle(.secondary)
                        Text("\(gameCount) / \(next)")
                            .font(.urbanist(.headline, weight: .bold))
                        ProgressView(value: Double(gameCount), total: Double(next))
                            .tint(Color.orange)
                    }
                }

                let recent = Array(achievedMilestones(for: events).suffix(5).reversed())
                if !recent.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Milestones")
                            .font(.urbanist(.subheadline, weight: .medium))

                        ForEach(recent, id: \.threshold) { milestone in
                            HStack {
                                Text("🏆")
                                    .font(.title3)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text("\(milestone.threshold)th \(milestone.type.rawValue)")
                                        .font(.urbanist(.subheadline, weight: .medium))
                                    Text(milestone.date, style: .date)
                                        .font(.urbanist(.caption))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .liquidGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
