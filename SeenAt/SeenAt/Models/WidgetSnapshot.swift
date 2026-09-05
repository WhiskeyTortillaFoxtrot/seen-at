import Foundation

struct WidgetGameSummary: Codable, Equatable, Sendable {
    let id: UUID
    let title: String
    let date: Date
    let jerseyCount: Int
}

struct WidgetTeamSummary: Codable, Equatable, Sendable {
    let name: String
    let abbreviation: String
    let colorHex: String
    let jerseyCount: Int
}

struct SeenAtWidgetSnapshot: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let generatedAt: Date
    let calendarYear: Int
    let seasonTotal: Int
    let allTimeTotal: Int
    let lastGame: WidgetGameSummary?
    let topTeam: WidgetTeamSummary?
    let latestStreakLength: Int
    let latestStreakDay: Date?

    static func empty(at date: Date = .now, calendar: Calendar = .current) -> Self {
        Self(
            schemaVersion: currentSchemaVersion,
            generatedAt: date,
            calendarYear: calendar.component(.year, from: date),
            seasonTotal: 0,
            allTimeTotal: 0,
            lastGame: nil,
            topTeam: nil,
            latestStreakLength: 0,
            latestStreakDay: nil
        )
    }

    func currentStreak(at date: Date = .now, calendar: Calendar = .hawaii) -> Int {
        guard let latestStreakDay else { return 0 }
        let latest = calendar.startOfDay(for: latestStreakDay)
        let today = calendar.startOfDay(for: date)
        let daysSinceLatest = calendar.dateComponents([.day], from: latest, to: today).day ?? .max
        return (0...1).contains(daysSinceLatest) ? latestStreakLength : 0
    }

    func season(at date: Date = .now, calendar: Calendar = .current) -> (year: Int, total: Int) {
        let year = calendar.component(.year, from: date)
        return (year, year == calendarYear ? seasonTotal : 0)
    }
}

enum WidgetSnapshotStore {
    static let appGroupIdentifier = "group.com.seenat.app"
    static let storageKey = "seenAtWidgetSnapshot.v1"

    static func load(from defaults: UserDefaults? = UserDefaults(suiteName: appGroupIdentifier)) -> SeenAtWidgetSnapshot {
        guard
            let data = defaults?.data(forKey: storageKey),
            let snapshot = try? JSONDecoder().decode(SeenAtWidgetSnapshot.self, from: data),
            snapshot.schemaVersion == SeenAtWidgetSnapshot.currentSchemaVersion
        else {
            return .empty()
        }
        return snapshot
    }

    @discardableResult
    static func save(
        _ snapshot: SeenAtWidgetSnapshot,
        to defaults: UserDefaults? = UserDefaults(suiteName: appGroupIdentifier)
    ) -> Bool {
        guard let defaults, let data = try? JSONEncoder().encode(snapshot) else { return false }
        defaults.set(data, forKey: storageKey)
        return true
    }
}

extension Calendar {
    static var hawaii: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Pacific/Honolulu")!
        return calendar
    }
}
