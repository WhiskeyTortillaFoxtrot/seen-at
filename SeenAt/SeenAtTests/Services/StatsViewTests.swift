import XCTest
@testable import SeenAt

final class StatsViewTests: XCTestCase {

    // MARK: - Streak Computation

    func testStreaksEmptyEvents() {
        let daily = computeStreaks(events: [], maxGapDays: 1)
        let weekly = computeStreaks(events: [], maxGapDays: 7)

        XCTAssertEqual(daily.current, 0)
        XCTAssertEqual(daily.longest, 0)
        XCTAssertEqual(weekly.current, 0)
        XCTAssertEqual(weekly.longest, 0)
    }

    func testStreaksSingleEvent() {
        let event = TestDataFactory.makeEvent(date: Date())

        let daily = computeStreaks(events: [event], maxGapDays: 1)
        XCTAssertEqual(daily.current, 1)
        XCTAssertEqual(daily.longest, 1)
    }

    func testStreaksConsecutiveDaily() {
        let calendar = Calendar.current
        let baseDate = requireDate(calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)))
        let events = (0..<5).map { offset in
            TestDataFactory.makeEvent(date: requireDate(calendar.date(byAdding: .day, value: offset, to: baseDate)))
        }

        let daily = computeStreaks(events: events, maxGapDays: 1)

        XCTAssertEqual(daily.current, 5)
        XCTAssertEqual(daily.longest, 5)
    }

    func testStreaksBrokenDaily() {
        let calendar = Calendar.current
        let baseDate = requireDate(calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)))
        let events = [
            TestDataFactory.makeEvent(date: baseDate),
            TestDataFactory.makeEvent(date: requireDate(calendar.date(byAdding: .day, value: 1, to: baseDate))),
            TestDataFactory.makeEvent(date: requireDate(calendar.date(byAdding: .day, value: 5, to: baseDate))),
            TestDataFactory.makeEvent(date: requireDate(calendar.date(byAdding: .day, value: 6, to: baseDate))),
        ]

        let daily = computeStreaks(events: events, maxGapDays: 1)

        XCTAssertEqual(daily.current, 2)
        XCTAssertEqual(daily.longest, 2)
    }

    func testStreaksWeeklyGap() {
        let calendar = Calendar.current
        let baseDate = requireDate(calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)))
        let events = [
            TestDataFactory.makeEvent(date: baseDate),
            TestDataFactory.makeEvent(date: requireDate(calendar.date(byAdding: .day, value: 3, to: baseDate))),
            TestDataFactory.makeEvent(date: requireDate(calendar.date(byAdding: .day, value: 8, to: baseDate))),
            TestDataFactory.makeEvent(date: requireDate(calendar.date(byAdding: .day, value: 12, to: baseDate))),
        ]

        let weekly = computeStreaks(events: events, maxGapDays: 7)

        XCTAssertEqual(weekly.current, 4)
        XCTAssertEqual(weekly.longest, 4)
    }

    func testStreaksWeeklyBroken() {
        let calendar = Calendar.current
        let baseDate = requireDate(calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)))
        let events = [
            TestDataFactory.makeEvent(date: baseDate),
            TestDataFactory.makeEvent(date: requireDate(calendar.date(byAdding: .day, value: 5, to: baseDate))),
            TestDataFactory.makeEvent(date: requireDate(calendar.date(byAdding: .day, value: 20, to: baseDate))),
        ]

        let weekly = computeStreaks(events: events, maxGapDays: 7)

        XCTAssertEqual(weekly.current, 1)
        XCTAssertEqual(weekly.longest, 2)
    }

    func testStreaksCurrentIsTrailingRun() {
        let calendar = Calendar.current
        let baseDate = requireDate(calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)))
        let events = [
            TestDataFactory.makeEvent(date: baseDate),
            TestDataFactory.makeEvent(date: requireDate(calendar.date(byAdding: .day, value: 1, to: baseDate))),
            TestDataFactory.makeEvent(date: requireDate(calendar.date(byAdding: .day, value: 2, to: baseDate))),
            TestDataFactory.makeEvent(date: requireDate(calendar.date(byAdding: .day, value: 10, to: baseDate))),
            TestDataFactory.makeEvent(date: requireDate(calendar.date(byAdding: .day, value: 11, to: baseDate))),
        ]

        let daily = computeStreaks(events: events, maxGapDays: 1)

        XCTAssertEqual(daily.current, 2)
        XCTAssertEqual(daily.longest, 3)
    }

    // MARK: - WatchLocation Split

    func testWatchLocationAllStadium() {
        let team = TestDataFactory.makeTeam()
        let event1 = TestDataFactory.makeEvent(date: Date())
        event1.watchLocation = .stadium
        let s1 = TestDataFactory.makeSighting(team: team, event: event1)
        event1.sightings = [s1]

        let event2 = TestDataFactory.makeEvent(date: Date())
        event2.watchLocation = .stadium
        let s2 = TestDataFactory.makeSighting(team: team, event: event2)
        event2.sightings = [s2]

        let events = [event1, event2]
        var stadium = 0
        var tv = 0
        for event in events {
            let count = event.sightings.count
            switch event.watchLocation {
            case .stadium, .none:
                stadium += count
            case .tv:
                tv += count
            }
        }

        XCTAssertEqual(stadium, 2)
        XCTAssertEqual(tv, 0)
    }

    func testWatchLocationMixed() {
        let team = TestDataFactory.makeTeam()
        let event1 = TestDataFactory.makeEvent(date: Date())
        event1.watchLocation = .stadium
        let s1a = TestDataFactory.makeSighting(team: team, event: event1)
        let s1b = TestDataFactory.makeSighting(team: team, event: event1)
        event1.sightings = [s1a, s1b]

        let event2 = TestDataFactory.makeEvent(date: Date())
        event2.watchLocation = .tv
        let s2 = TestDataFactory.makeSighting(team: team, event: event2)
        event2.sightings = [s2]

        let events = [event1, event2]
        var stadium = 0
        var tv = 0
        for event in events {
            let count = event.sightings.count
            switch event.watchLocation {
            case .stadium, .none:
                stadium += count
            case .tv:
                tv += count
            }
        }

        XCTAssertEqual(stadium, 2)
        XCTAssertEqual(tv, 1)
    }

    func testWatchLocationNilDefaultsToStadium() {
        let team = TestDataFactory.makeTeam()
        let event = TestDataFactory.makeEvent(date: Date())
        event.watchLocation = nil
        let s = TestDataFactory.makeSighting(team: team, event: event)
        event.sightings = [s]

        let events = [event]
        var stadium = 0
        var tv = 0
        for event in events {
            let count = event.sightings.count
            switch event.watchLocation {
            case .stadium, .none:
                stadium += count
            case .tv:
                tv += count
            }
        }

        XCTAssertEqual(stadium, 1)
        XCTAssertEqual(tv, 0)
    }

    // MARK: - Venue Rankings

    func testVenueTotalsOrdering() {
        let calendar = Calendar.current
        let baseDate = requireDate(calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)))

        let event1 = TestDataFactory.makeEvent(date: baseDate, venue: "Stadium A")
        let event2 = TestDataFactory.makeEvent(date: baseDate, venue: "Stadium B")
        let event3 = TestDataFactory.makeEvent(date: baseDate, venue: "Stadium A")
        let event4 = TestDataFactory.makeEvent(date: baseDate, venue: "Stadium C")
        let event5 = TestDataFactory.makeEvent(date: baseDate, venue: "Stadium A")
        let event6 = TestDataFactory.makeEvent(date: baseDate, venue: "Stadium B")

        let events = [event1, event2, event3, event4, event5, event6]
        let grouped = Dictionary(grouping: events.compactMap { $0.venue }) { $0 }
        let venueTotals = grouped
            .map { ($0.key, $0.value.count) }
            .sorted { $0.1 > $1.1 }

        XCTAssertEqual(venueTotals[0].0, "Stadium A")
        XCTAssertEqual(venueTotals[0].1, 3)
        XCTAssertEqual(venueTotals[1].0, "Stadium B")
        XCTAssertEqual(venueTotals[1].1, 2)
        XCTAssertEqual(venueTotals[2].0, "Stadium C")
        XCTAssertEqual(venueTotals[2].1, 1)
    }

    func testVenueTotalsNilVenueExcluded() {
        let calendar = Calendar.current
        let baseDate = requireDate(calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)))

        let event1 = TestDataFactory.makeEvent(date: baseDate, venue: "Stadium A")
        let event2 = TestDataFactory.makeEvent(date: baseDate, venue: nil)

        let events = [event1, event2]
        let grouped = Dictionary(grouping: events.compactMap { $0.venue }) { $0 }
        let venueTotals = grouped
            .map { ($0.key, $0.value.count) }
            .sorted { $0.1 > $1.1 }

        XCTAssertEqual(venueTotals.count, 1)
        XCTAssertEqual(venueTotals[0].0, "Stadium A")
    }

    // MARK: - Milestones

    func testMilestoneNextJerseyMilestone() {
        let calendar = Calendar.current
        let baseDate = requireDate(calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)))

        let team = TestDataFactory.makeTeam()
        let event = TestDataFactory.makeEvent(date: baseDate)
        let sightings = (0..<82).map { _ in TestDataFactory.makeSighting(team: team, event: event) }
        event.sightings = sightings

        let jerseyCount = totalJerseys(for: [event])

        XCTAssertEqual(jerseyCount, 82)
        XCTAssertEqual(nextJerseyMilestone(after: jerseyCount), 100)
    }

    func testMilestoneNextGameMilestone() {
        let calendar = Calendar.current
        let baseDate = requireDate(calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)))

        let events = (0..<23).map { offset in
            TestDataFactory.makeEvent(date: requireDate(calendar.date(byAdding: .day, value: offset, to: baseDate)))
        }

        let gameCount = totalGames(for: events)

        XCTAssertEqual(gameCount, 23)
        XCTAssertEqual(nextGameMilestone(after: gameCount), 25)
    }

    func testMilestoneAchievedJerseyMilestone() {
        let calendar = Calendar.current
        let baseDate = requireDate(calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)))

        let team = TestDataFactory.makeTeam()
        let event = TestDataFactory.makeEvent(date: baseDate)
        let sightings = (0..<100).map { _ in TestDataFactory.makeSighting(team: team, event: event) }
        event.sightings = sightings

        let milestones = achievedMilestones(for: [event]).filter { $0.type == .jerseys }

        XCTAssertTrue(milestones.contains { $0.threshold == 50 })
        XCTAssertTrue(milestones.contains { $0.threshold == 100 })
    }

    func testMilestoneAchievedGameMilestone() {
        let calendar = Calendar.current
        let baseDate = requireDate(calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)))

        let events = (0..<10).map { offset in
            TestDataFactory.makeEvent(date: requireDate(calendar.date(byAdding: .day, value: offset, to: baseDate)))
        }

        let milestones = achievedMilestones(for: events).filter { $0.type == .games }

        XCTAssertTrue(milestones.contains { $0.threshold == 10 })
    }

    func testMilestoneNoMilestonesYet() {
        let calendar = Calendar.current
        let baseDate = requireDate(calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)))

        let team = TestDataFactory.makeTeam()
        let event = TestDataFactory.makeEvent(date: baseDate)
        let sightings = (0..<5).map { _ in TestDataFactory.makeSighting(team: team, event: event) }
        event.sightings = sightings

        let events = [event]
        let jerseyCount = totalJerseys(for: events)
        let gameCount = totalGames(for: events)

        XCTAssertEqual(jerseyCount, 5)
        XCTAssertEqual(nextJerseyMilestone(after: jerseyCount), 50)
        XCTAssertEqual(gameCount, 1)
        XCTAssertEqual(nextGameMilestone(after: gameCount), 10)
        XCTAssertTrue(achievedMilestones(for: events).isEmpty)
    }

    func testMilestoneJerseyThresholdNotDoubleCounted() {
        let calendar = Calendar.current
        let baseDate = requireDate(calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)))

        let team = TestDataFactory.makeTeam()
        let event1 = TestDataFactory.makeEvent(date: baseDate)
        let s1 = (0..<48).map { _ in TestDataFactory.makeSighting(team: team, event: event1) }
        event1.sightings = s1

        let event2 = TestDataFactory.makeEvent(date: requireDate(calendar.date(byAdding: .day, value: 1, to: baseDate)))
        let s2 = (0..<5).map { _ in TestDataFactory.makeSighting(team: team, event: event2) }
        event2.sightings = s2

        let milestones = achievedMilestones(for: [event1, event2]).filter { $0.type == .jerseys }

        XCTAssertEqual(milestones.count, 1)
        XCTAssertEqual(milestones.first?.threshold, 50)
    }

    // MARK: - Trend Aggregation

    func testTrendPerGameAggregation() {
        let calendar = Calendar.current
        let baseDate = requireDate(calendar.date(from: DateComponents(year: 2025, month: 1, day: 1)))

        let team = TestDataFactory.makeTeam()
        let event1 = TestDataFactory.makeEvent(date: baseDate)
        let event2 = TestDataFactory.makeEvent(date: requireDate(calendar.date(byAdding: .day, value: 2, to: baseDate)))
        let event3 = TestDataFactory.makeEvent(date: requireDate(calendar.date(byAdding: .day, value: 5, to: baseDate)))

        let s1 = (0..<3).map { _ in TestDataFactory.makeSighting(team: team, event: event1) }
        event1.sightings = s1
        let s2 = (0..<2).map { _ in TestDataFactory.makeSighting(team: team, event: event2) }
        event2.sightings = s2
        let s3 = (0..<5).map { _ in TestDataFactory.makeSighting(team: team, event: event3) }
        event3.sightings = s3

        let events = [event1, event2, event3]
        let sortedEvents = events.sorted { $0.date < $1.date }
        let chartData = sortedEvents.map { event in
            (label: "", count: event.sightings.count)
        }

        XCTAssertEqual(chartData.count, 3)
        XCTAssertEqual(chartData[0].count, 3)
        XCTAssertEqual(chartData[1].count, 2)
        XCTAssertEqual(chartData[2].count, 5)
    }

    func testTrendPerMonthAggregation() {
        let calendar = Calendar.current
        let janDate = requireDate(calendar.date(from: DateComponents(year: 2025, month: 1, day: 15)))
        let febDate = requireDate(calendar.date(from: DateComponents(year: 2025, month: 2, day: 10)))

        let team = TestDataFactory.makeTeam()
        let event1 = TestDataFactory.makeEvent(date: janDate)
        let event2 = TestDataFactory.makeEvent(date: requireDate(calendar.date(byAdding: .day, value: 5, to: janDate)))
        let event3 = TestDataFactory.makeEvent(date: febDate)

        let s1 = (0..<3).map { _ in TestDataFactory.makeSighting(team: team, event: event1) }
        event1.sightings = s1
        let s2 = (0..<2).map { _ in TestDataFactory.makeSighting(team: team, event: event2) }
        event2.sightings = s2
        let s3 = (0..<5).map { _ in TestDataFactory.makeSighting(team: team, event: event3) }
        event3.sightings = s3

        let events = [event1, event2, event3]
        let grouped = Dictionary(grouping: events) { event in
            let components = calendar.dateComponents([.year, .month], from: event.date)
            return calendar.date(from: components) ?? event.date
        }
        let sortedDates = grouped.keys.sorted()
        let chartData = sortedDates.map { date in
            let count = grouped[date]?.reduce(0) { $0 + $1.sightings.count } ?? 0
            return (label: "", count: count)
        }

        XCTAssertEqual(chartData.count, 2)
        XCTAssertEqual(chartData[0].count, 5)
        XCTAssertEqual(chartData[1].count, 5)
    }

    func testTrendPerYearAggregation() {
        let calendar = Calendar.current
        let date2024 = requireDate(calendar.date(from: DateComponents(year: 2024, month: 6, day: 15)))
        let date2025 = requireDate(calendar.date(from: DateComponents(year: 2025, month: 3, day: 10)))

        let team = TestDataFactory.makeTeam()
        let event1 = TestDataFactory.makeEvent(date: date2024)
        let event2 = TestDataFactory.makeEvent(date: date2025)
        let event3 = TestDataFactory.makeEvent(date: requireDate(calendar.date(byAdding: .month, value: 6, to: date2025)))

        let s1 = (0..<3).map { _ in TestDataFactory.makeSighting(team: team, event: event1) }
        event1.sightings = s1
        let s2 = (0..<2).map { _ in TestDataFactory.makeSighting(team: team, event: event2) }
        event2.sightings = s2
        let s3 = (0..<5).map { _ in TestDataFactory.makeSighting(team: team, event: event3) }
        event3.sightings = s3

        let events = [event1, event2, event3]
        let grouped = Dictionary(grouping: events) { event in
            calendar.component(.year, from: event.date)
        }
        let sortedYears = grouped.keys.sorted()
        let chartData = sortedYears.map { year in
            let count = grouped[year]?.reduce(0) { $0 + $1.sightings.count } ?? 0
            return (label: "\(year)", count: count)
        }

        XCTAssertEqual(chartData.count, 2)
        XCTAssertEqual(chartData[0].label, "2024")
        XCTAssertEqual(chartData[0].count, 3)
        XCTAssertEqual(chartData[1].label, "2025")
        XCTAssertEqual(chartData[1].count, 7)
    }

    // MARK: - Year Filtering

    func testYearFiltering() {
        let calendar = Calendar.current
        let date2024 = requireDate(calendar.date(from: DateComponents(year: 2024, month: 6, day: 15)))
        let date2025a = requireDate(calendar.date(from: DateComponents(year: 2025, month: 3, day: 10)))
        let date2025b = requireDate(calendar.date(from: DateComponents(year: 2025, month: 9, day: 20)))

        let team = TestDataFactory.makeTeam()
        let event1 = TestDataFactory.makeEvent(date: date2024)
        let event2 = TestDataFactory.makeEvent(date: date2025a)
        let event3 = TestDataFactory.makeEvent(date: date2025b)

        let s1 = TestDataFactory.makeSighting(team: team, event: event1)
        event1.sightings = [s1]
        let s2 = TestDataFactory.makeSighting(team: team, event: event2)
        event2.sightings = [s2]
        let s3 = TestDataFactory.makeSighting(team: team, event: event3)
        event3.sightings = [s3]

        let allEvents = [event1, event2, event3]

        let filtered2024 = allEvents.filter { calendar.component(.year, from: $0.date) == 2024 }
        let filtered2025 = allEvents.filter { calendar.component(.year, from: $0.date) == 2025 }

        XCTAssertEqual(filtered2024.count, 1)
        XCTAssertEqual(filtered2025.count, 2)
        XCTAssertEqual(allEvents.count, 3)
    }

    func testYearFilteringSightings() {
        let calendar = Calendar.current
        let date2024 = requireDate(calendar.date(from: DateComponents(year: 2024, month: 6, day: 15)))
        let date2025 = requireDate(calendar.date(from: DateComponents(year: 2025, month: 3, day: 10)))

        let team = TestDataFactory.makeTeam()
        let event1 = TestDataFactory.makeEvent(date: date2024)
        let event2 = TestDataFactory.makeEvent(date: date2025)

        let s1 = (0..<5).map { _ in TestDataFactory.makeSighting(team: team, event: event1) }
        event1.sightings = s1
        let s2 = (0..<3).map { _ in TestDataFactory.makeSighting(team: team, event: event2) }
        event2.sightings = s2

        let allEvents = [event1, event2]

        let filtered2024 = allEvents.filter { calendar.component(.year, from: $0.date) == 2024 }
        let filtered2025 = allEvents.filter { calendar.component(.year, from: $0.date) == 2025 }

        let sightings2024 = filtered2024.reduce(0) { $0 + $1.sightings.count }
        let sightings2025 = filtered2025.reduce(0) { $0 + $1.sightings.count }

        XCTAssertEqual(sightings2024, 5)
        XCTAssertEqual(sightings2025, 3)
    }

    private func requireDate(
        _ date: Date?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Date {
        guard let date else {
            XCTFail("Expected a valid test date", file: file, line: line)
            return .distantPast
        }
        return date
    }
}
