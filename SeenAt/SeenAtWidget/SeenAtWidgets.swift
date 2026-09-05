import SwiftUI
import WidgetKit

@main
struct SeenAtWidgetBundle: WidgetBundle {
    var body: some Widget {
        SeenAtLiveActivity()
        SeasonTotalWidget()
        LastGameWidget()
        TopTeamWidget()
        StreakWidget()
    }
}

struct WidgetSnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: SeenAtWidgetSnapshot
}

struct WidgetSnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> WidgetSnapshotEntry {
        WidgetSnapshotEntry(date: .now, snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetSnapshotEntry) -> Void) {
        completion(WidgetSnapshotEntry(date: .now, snapshot: context.isPreview ? .preview : WidgetSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetSnapshotEntry>) -> Void) {
        let now = Date.now
        let entry = WidgetSnapshotEntry(date: now, snapshot: WidgetSnapshotStore.load())
        completion(Timeline(entries: [entry], policy: .after(Self.nextDayBoundary(after: now))))
    }

    static func nextDayBoundary(after date: Date) -> Date {
        let calendars = [Calendar.current, Calendar.hawaii]
        return calendars.compactMap { calendar in
            calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))
        }.min() ?? date.addingTimeInterval(86_400)
    }
}

struct SeasonTotalWidget: Widget {
    let kind = "SeasonTotalWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidgetSnapshotProvider()) { entry in
            SeasonTotalWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "seenat://stats"))
        }
        .configurationDisplayName("Season Total")
        .description("Jerseys seen during the current calendar year.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct SeasonTotalWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WidgetSnapshotEntry

    private var season: (year: Int, total: Int) {
        entry.snapshot.season(at: entry.date)
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Label("Season Total", systemImage: "tshirt.fill")
                    .font(.urbanist(.caption, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("\(season.total)")
                    .font(.urbanist(size: 42, weight: .bold))
                    .minimumScaleFactor(0.6)
                Text("jerseys in \(season.year)")
                    .font(.urbanist(.caption))
                    .foregroundStyle(.secondary)
            }
            if family == .systemMedium {
                Spacer()
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
            }
        }
    }
}

struct LastGameWidget: Widget {
    let kind = "LastGameWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidgetSnapshotProvider()) { entry in
            LastGameWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(lastGameURL(for: entry.snapshot))
        }
        .configurationDisplayName("Last Game")
        .description("A summary of your most recently tracked game.")
        .supportedFamilies([.systemMedium])
    }

    private func lastGameURL(for snapshot: SeenAtWidgetSnapshot) -> URL? {
        guard let id = snapshot.lastGame?.id else { return nil }
        return URL(string: "seenat://event-summary/\(id.uuidString)")
    }
}

private struct LastGameWidgetView: View {
    let entry: WidgetSnapshotEntry

    var body: some View {
        if let game = entry.snapshot.lastGame {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Last Game", systemImage: "clock.arrow.circlepath")
                        .font(.urbanist(.caption, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(game.title)
                        .font(.urbanist(.headline, weight: .bold))
                        .lineLimit(2)
                    Text(game.date, format: .dateTime.month(.abbreviated).day().year())
                        .font(.urbanist(.caption))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                VStack(spacing: 2) {
                    Text("\(game.jerseyCount)")
                        .font(.urbanist(size: 36, weight: .bold))
                    Text(game.jerseyCount == 1 ? "jersey" : "jerseys")
                        .font(.urbanist(.caption))
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            WidgetEmptyView(title: "No games yet", systemImage: "sportscourt")
        }
    }
}

struct TopTeamWidget: Widget {
    let kind = "TopTeamWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidgetSnapshotProvider()) { entry in
            TopTeamWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "seenat://stats"))
        }
        .configurationDisplayName("Top Team")
        .description("Your most-seen team across all tracked games.")
        .supportedFamilies([.systemMedium])
    }
}

private struct TopTeamWidgetView: View {
    let entry: WidgetSnapshotEntry

    var body: some View {
        if let team = entry.snapshot.topTeam {
            HStack(spacing: 18) {
                ZStack {
                    Circle()
                        .stroke(.secondary.opacity(0.2), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: share(for: team))
                        .stroke(widgetColor(team.colorHex), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(team.abbreviation)
                        .font(.urbanist(.headline, weight: .bold))
                        .minimumScaleFactor(0.6)
                }
                .frame(width: 76, height: 76)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Label("Top Team", systemImage: "trophy.fill")
                        .font(.urbanist(.caption, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(team.name)
                        .font(.urbanist(.headline, weight: .bold))
                        .lineLimit(2)
                    Text("\(team.jerseyCount) jersey\(team.jerseyCount == 1 ? "" : "s")")
                        .font(.urbanist(.caption))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        } else {
            WidgetEmptyView(title: "No teams yet", systemImage: "trophy")
        }
    }

    private func share(for team: WidgetTeamSummary) -> Double {
        guard entry.snapshot.allTimeTotal > 0 else { return 0 }
        return min(1, Double(team.jerseyCount) / Double(entry.snapshot.allTimeTotal))
    }
}

struct StreakWidget: Widget {
    let kind = "StreakWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WidgetSnapshotProvider()) { entry in
            StreakWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "seenat://stats"))
        }
        .configurationDisplayName("Tracking Streak")
        .description("Consecutive Hawaii calendar days with at least one tracked game.")
        .supportedFamilies([.accessoryRectangular, .accessoryCircular])
    }
}

private struct StreakWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WidgetSnapshotEntry

    private var streak: Int {
        entry.snapshot.currentStreak(at: entry.date)
    }

    var body: some View {
        if family == .accessoryCircular {
            VStack(spacing: 0) {
                Image(systemName: "flame.fill")
                    .font(.caption)
                Text("\(streak)")
                    .font(.urbanist(.title3, weight: .bold))
            }
            .widgetAccentable()
            .accessibilityLabel("\(streak) day tracking streak")
        } else {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.title3)
                    .widgetAccentable()
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(streak) day\(streak == 1 ? "" : "s")")
                        .font(.urbanist(.headline, weight: .bold))
                    Text("tracking streak")
                        .font(.urbanist(.caption2))
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}

private struct WidgetEmptyView: View {
    let title: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.urbanist(.headline, weight: .semibold))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private func widgetColor(_ hex: String) -> Color {
    let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else { return .gray }
    return Color(
        red: Double((value >> 16) & 0xFF) / 255,
        green: Double((value >> 8) & 0xFF) / 255,
        blue: Double(value & 0xFF) / 255
    )
}

private extension SeenAtWidgetSnapshot {
    static let preview: Self = {
        let gameID = UUID(uuidString: "00000000-0000-0000-0000-000000000055")!
        return Self(
            schemaVersion: currentSchemaVersion,
            generatedAt: .now,
            calendarYear: Calendar.current.component(.year, from: .now),
            seasonTotal: 127,
            allTimeTotal: 240,
            lastGame: WidgetGameSummary(id: gameID, title: "CHC @ STL", date: .now, jerseyCount: 18),
            topTeam: WidgetTeamSummary(
                name: "Chicago Cubs",
                abbreviation: "CHC",
                colorHex: "#0E3386",
                jerseyCount: 42
            ),
            latestStreakLength: 4,
            latestStreakDay: .now
        )
    }()
}
