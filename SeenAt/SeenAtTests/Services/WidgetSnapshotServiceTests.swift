import XCTest
@testable import SeenAt

final class WidgetSnapshotServiceTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testSnapshotUsesCurrentCalendarYearForSeasonTotal() throws {
        let now = try date("2026-09-04T12:00:00Z")
        let cubs = WidgetSightingInput(teamName: "Chicago Cubs", teamAbbreviation: "CHC", teamColorHex: "#0E3386")
        let events = [
            WidgetEventInput(title: "Current year", date: try date("2026-04-01T12:00:00Z"), sightings: [cubs, cubs]),
            WidgetEventInput(title: "Previous year", date: try date("2025-12-31T23:00:00Z"), sightings: [cubs]),
            WidgetEventInput(title: "Upcoming", date: try date("2026-10-01T12:00:00Z"), sightings: [cubs])
        ]

        let snapshot = WidgetSnapshotService.makeSnapshot(events: events, now: now, calendar: calendar)

        XCTAssertEqual(snapshot.calendarYear, 2026)
        XCTAssertEqual(snapshot.seasonTotal, 2)
        XCTAssertEqual(snapshot.allTimeTotal, 3)
        XCTAssertEqual(snapshot.lastGame?.title, "Current year")
    }

    func testSnapshotSelectsTopTeamWithStableTieBreaking() throws {
        let now = try date("2026-09-04T12:00:00Z")
        let alpha = WidgetSightingInput(teamName: "Alpha", teamAbbreviation: "A", teamColorHex: "#111111")
        let beta = WidgetSightingInput(teamName: "Beta", teamAbbreviation: "B", teamColorHex: "#222222")
        let event = WidgetEventInput(
            title: "Game",
            date: try date("2026-09-01T12:00:00Z"),
            sightings: [beta, alpha, beta, alpha]
        )

        let snapshot = WidgetSnapshotService.makeSnapshot(events: [event], now: now, calendar: calendar)

        XCTAssertEqual(snapshot.topTeam?.name, "Alpha")
        XCTAssertEqual(snapshot.topTeam?.jerseyCount, 2)
    }

    func testStreakUsesEventStartTimeAndHawaiiMidnight() throws {
        let now = try date("2026-09-04T20:00:00Z")
        let events = [
            // September 2 at 11:30 PM in Hawaii.
            WidgetEventInput(title: "First", date: try date("2026-09-03T09:30:00Z")),
            // September 3 at 12:30 AM in Hawaii.
            WidgetEventInput(title: "Second", date: try date("2026-09-03T10:30:00Z")),
            // Same Hawaii calendar day; this must not add another streak day.
            WidgetEventInput(title: "Third", date: try date("2026-09-04T05:00:00Z"))
        ]

        let snapshot = WidgetSnapshotService.makeSnapshot(events: events, now: now, streakCalendar: .hawaii)

        XCTAssertEqual(snapshot.latestStreakLength, 2)
        XCTAssertEqual(snapshot.currentStreak(at: now), 2)
    }

    func testCurrentStreakExpiresAfterOneUntrackedDay() throws {
        let latestDay = try date("2026-09-01T10:00:00Z")
        let snapshot = SeenAtWidgetSnapshot(
            schemaVersion: SeenAtWidgetSnapshot.currentSchemaVersion,
            generatedAt: latestDay,
            calendarYear: 2026,
            seasonTotal: 0,
            allTimeTotal: 0,
            lastGame: nil,
            topTeam: nil,
            latestStreakLength: 3,
            latestStreakDay: latestDay
        )

        XCTAssertEqual(snapshot.currentStreak(at: try date("2026-09-02T10:00:00Z")), 3)
        XCTAssertEqual(snapshot.currentStreak(at: try date("2026-09-03T10:00:00Z")), 0)
    }

    func testSeasonRollsToZeroUntilAppPublishesTheNewCalendarYear() throws {
        let snapshot = SeenAtWidgetSnapshot(
            schemaVersion: SeenAtWidgetSnapshot.currentSchemaVersion,
            generatedAt: try date("2026-12-31T12:00:00Z"),
            calendarYear: 2026,
            seasonTotal: 10,
            allTimeTotal: 10,
            lastGame: nil,
            topTeam: nil,
            latestStreakLength: 0,
            latestStreakDay: nil
        )

        let season = snapshot.season(at: try date("2027-01-01T12:00:00Z"), calendar: calendar)

        XCTAssertEqual(season.year, 2027)
        XCTAssertEqual(season.total, 0)
    }

    func testSnapshotStoreRoundTripsVersionedData() throws {
        let suiteName = "WidgetSnapshotServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let snapshot = SeenAtWidgetSnapshot.empty(at: try date("2026-09-04T12:00:00Z"), calendar: calendar)

        XCTAssertTrue(WidgetSnapshotStore.save(snapshot, to: defaults))
        XCTAssertEqual(WidgetSnapshotStore.load(from: defaults), snapshot)
    }

    private func date(_ value: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: value))
    }
}
