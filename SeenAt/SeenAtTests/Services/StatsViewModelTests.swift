import XCTest
@testable import SeenAt

@MainActor
final class StatsViewModelTests: XCTestCase {
    func testUpdateCalculatesAllTimeTotals() {
        let team = TestDataFactory.makeTeam(name: "Cards", sport: "mlb")
        let firstEvent = TestDataFactory.makeEvent(date: date(year: 2024), venue: "Stadium A")
        let secondEvent = TestDataFactory.makeEvent(date: date(year: 2025), venue: "Stadium A")
        firstEvent.sightings = [
            TestDataFactory.makeSighting(team: team, event: firstEvent),
            TestDataFactory.makeSighting(team: team, firstName: "Sam", lastName: "Player", event: firstEvent)
        ]
        secondEvent.sightings = [TestDataFactory.makeSighting(team: team, event: secondEvent)]

        let viewModel = StatsViewModel()
        let events = [secondEvent, firstEvent]
        viewModel.update(key: StatsCacheKey(events: events, selectedYear: nil), events: events)

        XCTAssertTrue(viewModel.hasLoaded)
        XCTAssertEqual(viewModel.availableYears, [2025, 2024])
        XCTAssertEqual(viewModel.totalGames, 2)
        XCTAssertEqual(viewModel.totalSightings, 3)
        XCTAssertEqual(viewModel.teamTotals.first?.team.name, "Cards")
        XCTAssertEqual(viewModel.teamTotals.first?.count, 3)
        XCTAssertEqual(viewModel.leagueTotals.first?.sport, "MLB")
        XCTAssertEqual(viewModel.leagueTotals.first?.count, 3)
        XCTAssertEqual(viewModel.venueTotals.first?.venue, "Stadium A")
        XCTAssertEqual(viewModel.venueTotals.first?.count, 2)
        XCTAssertEqual(viewModel.topPlayers.first?.name, "Sam Player")
        XCTAssertEqual(viewModel.topPlayers.first?.count, 1)
    }

    func testUpdateFiltersBySelectedYear() {
        let team = TestDataFactory.makeTeam()
        let event2024 = TestDataFactory.makeEvent(date: date(year: 2024))
        let event2025 = TestDataFactory.makeEvent(date: date(year: 2025))
        event2024.sightings = [TestDataFactory.makeSighting(team: team, event: event2024)]
        event2025.sightings = [
            TestDataFactory.makeSighting(team: team, event: event2025),
            TestDataFactory.makeSighting(team: team, event: event2025)
        ]

        let viewModel = StatsViewModel()
        let events = [event2025, event2024]
        viewModel.update(key: StatsCacheKey(events: events, selectedYear: 2025), events: events)

        XCTAssertEqual(viewModel.filteredEvents.count, 1)
        XCTAssertEqual(viewModel.totalGames, 1)
        XCTAssertEqual(viewModel.totalSightings, 2)
        XCTAssertEqual(viewModel.teamTotals.first?.count, 2)
    }

    func testUpdateInvalidatesWhenSightingChanges() {
        let team = TestDataFactory.makeTeam()
        let event = TestDataFactory.makeEvent(date: date(year: 2025))
        event.sightings = [TestDataFactory.makeSighting(team: team, event: event)]

        let viewModel = StatsViewModel()
        let events = [event]
        viewModel.update(key: StatsCacheKey(events: events, selectedYear: nil), events: events)
        XCTAssertEqual(viewModel.totalSightings, 1)

        event.sightings.append(TestDataFactory.makeSighting(team: team, event: event))
        viewModel.update(key: StatsCacheKey(events: events, selectedYear: nil), events: events)

        XCTAssertEqual(viewModel.totalSightings, 2)
        XCTAssertEqual(viewModel.teamTotals.first?.count, 2)
    }

    func testUpdateCalculatesWatchLocationTotals() {
        let team = TestDataFactory.makeTeam()
        let stadiumEvent = TestDataFactory.makeEvent()
        stadiumEvent.watchLocation = .stadium
        stadiumEvent.sightings = [TestDataFactory.makeSighting(team: team, event: stadiumEvent)]

        let tvEvent = TestDataFactory.makeEvent()
        tvEvent.watchLocation = .tv
        tvEvent.sightings = [
            TestDataFactory.makeSighting(team: team, event: tvEvent),
            TestDataFactory.makeSighting(team: team, event: tvEvent)
        ]

        let nilLocationEvent = TestDataFactory.makeEvent()
        nilLocationEvent.watchLocation = nil
        nilLocationEvent.sightings = [TestDataFactory.makeSighting(team: team, event: nilLocationEvent)]

        let events = [stadiumEvent, tvEvent, nilLocationEvent]
        let viewModel = StatsViewModel()
        viewModel.update(key: StatsCacheKey(events: events, selectedYear: nil), events: events)

        XCTAssertEqual(viewModel.watchLocationTotals.stadium, 2)
        XCTAssertEqual(viewModel.watchLocationTotals.tv, 2)
    }

    func testUpdateLimitsVenueTotalsToTen() {
        let venues = ["Venue A", "Venue B", "Venue C", "Venue D", "Venue E", "Venue F", "Venue G", "Venue H", "Venue I", "Venue J", "Venue K", "Venue L"]
        let events = venues.map { venue in
            TestDataFactory.makeEvent(venue: venue)
        }
        let viewModel = StatsViewModel()
        viewModel.update(key: StatsCacheKey(events: events, selectedYear: nil), events: events)

        XCTAssertEqual(viewModel.venueTotals.count, 10)
        XCTAssertEqual(viewModel.venueTotals.first?.venue, "Venue A")
        XCTAssertFalse(viewModel.venueTotals.contains { $0.venue == "Venue L" })
    }

    func testUpdateLimitsTopPlayersToFive() {
        let team = TestDataFactory.makeTeam()
        let event = TestDataFactory.makeEvent()
        event.sightings = (1...7).map { index in
            TestDataFactory.makeSighting(
                team: team,
                firstName: "Player",
                lastName: "\(index)",
                event: event
            )
        }

        let events = [event]
        let viewModel = StatsViewModel()
        viewModel.update(key: StatsCacheKey(events: events, selectedYear: nil), events: events)

        XCTAssertEqual(viewModel.topPlayers.count, 5)
    }

    func testUpdateComputesAvailableYearsDescending() {
        let events = [
            TestDataFactory.makeEvent(date: date(year: 2023)),
            TestDataFactory.makeEvent(date: date(year: 2025)),
            TestDataFactory.makeEvent(date: date(year: 2024))
        ]
        let viewModel = StatsViewModel()
        viewModel.update(key: StatsCacheKey(events: events, selectedYear: nil), events: events)

        XCTAssertEqual(viewModel.availableYears, [2025, 2024, 2023])
    }

    func testUpdateGroupsTeamsByName() {
        let firstTeam = TestDataFactory.makeTeam(name: "Cards")
        let secondTeam = TestDataFactory.makeTeam(name: "Cards")
        let event = TestDataFactory.makeEvent()
        event.sightings = [
            TestDataFactory.makeSighting(team: firstTeam, event: event),
            TestDataFactory.makeSighting(team: secondTeam, event: event)
        ]

        let events = [event]
        let viewModel = StatsViewModel()
        viewModel.update(key: StatsCacheKey(events: events, selectedYear: nil), events: events)

        XCTAssertEqual(viewModel.teamTotals.count, 1)
        XCTAssertEqual(viewModel.teamTotals.first?.team.name, "Cards")
        XCTAssertEqual(viewModel.teamTotals.first?.count, 2)
    }

    private func date(year: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: 6, day: 15))!
    }
}
