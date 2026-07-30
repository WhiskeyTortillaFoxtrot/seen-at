import SwiftUI

struct StreakResult {
    let current: Int
    let longest: Int
}

func computeStreaks(events: [Event], maxGapDays: Int) -> StreakResult {
    let sortedEvents = events.sorted { $0.date < $1.date }
    guard !sortedEvents.isEmpty else { return StreakResult(current: 0, longest: 0) }

    let calendar = Calendar.current
    var longest = 1
    var currentRun = 1

    for i in 1..<sortedEvents.count {
        let prevDate = sortedEvents[i - 1].date
        let currDate = sortedEvents[i].date
        let gap = calendar.dateComponents([.day], from: prevDate, to: currDate).day ?? 0

        if gap <= maxGapDays {
            currentRun += 1
            longest = max(longest, currentRun)
        } else {
            currentRun = 1
        }
    }

    var currentStreak = 1
    for i in (1..<sortedEvents.count).reversed() {
        let prevDate = sortedEvents[i - 1].date
        let currDate = sortedEvents[i].date
        let gap = calendar.dateComponents([.day], from: prevDate, to: currDate).day ?? 0

        if gap <= maxGapDays {
            currentStreak += 1
        } else {
            break
        }
    }

    return StreakResult(current: currentStreak, longest: longest)
}

struct StatsStreakCard: View {
    let events: [Event]

    private var dailyStreak: StreakResult {
        computeStreaks(events: events, maxGapDays: 1)
    }

    private var weeklyStreak: StreakResult {
        computeStreaks(events: events, maxGapDays: 7)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Streaks")
                .font(.urbanist(.headline))

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Text("🔥")
                        .font(.title3)
                    Text("Daily (consecutive days)")
                        .font(.urbanist(.subheadline, weight: .medium))
                }
                Text("Current: \(dailyStreak.current) game\(dailyStreak.current == 1 ? "" : "s")")
                    .font(.urbanist(.subheadline))
                    .foregroundStyle(.secondary)
                Text("Longest: \(dailyStreak.longest) game\(dailyStreak.longest == 1 ? "" : "s")")
                    .font(.urbanist(.subheadline))
                    .foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Text("📅")
                        .font(.title3)
                    Text("Weekly (at least 1 game per 7 days)")
                        .font(.urbanist(.subheadline, weight: .medium))
                }
                Text("Current: \(weeklyStreak.current) week\(weeklyStreak.current == 1 ? "" : "s")")
                    .font(.urbanist(.subheadline))
                    .foregroundStyle(.secondary)
                Text("Longest: \(weeklyStreak.longest) week\(weeklyStreak.longest == 1 ? "" : "s")")
                    .font(.urbanist(.subheadline))
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}
