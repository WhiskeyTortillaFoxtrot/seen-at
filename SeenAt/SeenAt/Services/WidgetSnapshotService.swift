import Foundation
import WidgetKit

struct WidgetSightingInput: Equatable {
    let teamName: String?
    let teamAbbreviation: String?
    let teamColorHex: String?

    init(sighting: JerseySighting) {
        teamName = sighting.team?.name
        teamAbbreviation = sighting.team?.abbreviation
        teamColorHex = sighting.team?.primaryColorHex
    }

    init(teamName: String?, teamAbbreviation: String? = nil, teamColorHex: String? = nil) {
        self.teamName = teamName
        self.teamAbbreviation = teamAbbreviation
        self.teamColorHex = teamColorHex
    }
}

struct WidgetEventInput: Equatable {
    let id: UUID
    let title: String
    let date: Date
    let sightings: [WidgetSightingInput]

    init(event: Event) {
        id = event.id
        title = event.title
        date = event.date
        sightings = event.sightings.map(WidgetSightingInput.init)
    }

    init(id: UUID = UUID(), title: String, date: Date, sightings: [WidgetSightingInput] = []) {
        self.id = id
        self.title = title
        self.date = date
        self.sightings = sightings
    }
}

enum WidgetSnapshotService {
    static func makeSnapshot(
        events: [WidgetEventInput],
        now: Date = .now,
        calendar: Calendar = .current,
        streakCalendar: Calendar = .hawaii
    ) -> SeenAtWidgetSnapshot {
        let completedEvents = events.filter { $0.date <= now }
        let currentYear = calendar.component(.year, from: now)
        let seasonEvents = completedEvents.filter { calendar.component(.year, from: $0.date) == currentYear }
        let allSightings = completedEvents.flatMap(\.sightings)

        let lastGame = completedEvents.max { lhs, rhs in
            lhs.date == rhs.date ? lhs.id.uuidString < rhs.id.uuidString : lhs.date < rhs.date
        }.map {
            WidgetGameSummary(id: $0.id, title: $0.title, date: $0.date, jerseyCount: $0.sightings.count)
        }

        var groupedTeams: [String: [WidgetSightingInput]] = [:]
        for sighting in allSightings {
            guard let name = sighting.teamName else { continue }
            groupedTeams[name, default: []].append(sighting)
        }
        let teamSummaries = groupedTeams.map { name, sightings -> WidgetTeamSummary in
            let first = sightings[0]
            return WidgetTeamSummary(
                name: name,
                abbreviation: first.teamAbbreviation ?? name,
                colorHex: first.teamColorHex ?? "#808080",
                jerseyCount: sightings.count
            )
        }
        let topTeam = teamSummaries.sorted(by: isHigherRankingTeam).first

        let streak = latestStreak(events: completedEvents, calendar: streakCalendar)
        return SeenAtWidgetSnapshot(
            schemaVersion: SeenAtWidgetSnapshot.currentSchemaVersion,
            generatedAt: now,
            calendarYear: currentYear,
            seasonTotal: seasonEvents.reduce(0) { $0 + $1.sightings.count },
            allTimeTotal: allSightings.count,
            lastGame: lastGame,
            topTeam: topTeam,
            latestStreakLength: streak.length,
            latestStreakDay: streak.latestDay
        )
    }

    @MainActor
    static func publish(events: [WidgetEventInput], now: Date = .now) {
        let snapshot = makeSnapshot(events: events, now: now)
        guard WidgetSnapshotStore.save(snapshot) else {
            DiagnosticsService.shared.log(
                category: "Widget",
                level: .warning,
                message: "Could not write the widget snapshot to the App Group"
            )
            return
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func latestStreak(
        events: [WidgetEventInput],
        calendar: Calendar
    ) -> (length: Int, latestDay: Date?) {
        let days = Set(events.map { calendar.startOfDay(for: $0.date) }).sorted(by: >)
        guard let latestDay = days.first else { return (0, nil) }

        var length = 1
        var previous = latestDay
        for day in days.dropFirst() {
            let gap = calendar.dateComponents([.day], from: day, to: previous).day ?? .max
            guard gap == 1 else { break }
            length += 1
            previous = day
        }
        return (length, latestDay)
    }

    private static func isHigherRankingTeam(_ lhs: WidgetTeamSummary, _ rhs: WidgetTeamSummary) -> Bool {
        lhs.jerseyCount > rhs.jerseyCount || (lhs.jerseyCount == rhs.jerseyCount && lhs.name < rhs.name)
    }
}
