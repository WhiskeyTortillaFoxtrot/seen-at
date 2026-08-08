import XCTest
@testable import SeenAt
import SwiftData

@MainActor
final class SearchViewTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        container = TestModelContainer.create()
        context = container.mainContext
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    func testSearchByEventTitle() {
        let event = TestDataFactory.makeEvent(title: "NYY @ BOS")
        context.insert(event)
        try? context.save()

        let predicate = #Predicate<Event> { event in
            event.title.localizedStandardContains("NYY")
        }
        let descriptor = FetchDescriptor<Event>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let results = (try? context.fetch(descriptor)) ?? []

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "NYY @ BOS")
    }

    func testSearchByEventTitlePartial() {
        let event = TestDataFactory.makeEvent(title: "CHC @ STL")
        context.insert(event)
        try? context.save()

        let predicate = #Predicate<Event> { event in
            event.title.localizedStandardContains("chc")
        }
        let descriptor = FetchDescriptor<Event>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let results = (try? context.fetch(descriptor)) ?? []

        XCTAssertEqual(results.count, 1)
    }

    func testSearchByEventTitleNoMatch() {
        let event = TestDataFactory.makeEvent(title: "NYY @ BOS")
        context.insert(event)
        try? context.save()

        let predicate = #Predicate<Event> { event in
            event.title.localizedStandardContains("LAD")
        }
        let descriptor = FetchDescriptor<Event>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let results = (try? context.fetch(descriptor)) ?? []

        XCTAssertEqual(results.count, 0)
    }

    func testSearchByPlayerFirstName() {
        let event = TestDataFactory.makeEvent()
        context.insert(event)
        let sighting = TestDataFactory.makeSighting(firstName: "Shohei", lastName: "Ohtani", event: event)
        context.insert(sighting)
        try? context.save()

        let predicate = #Predicate<JerseySighting> { sighting in
            sighting.firstName?.localizedStandardContains("Shohei") == true ||
            sighting.lastName?.localizedStandardContains("Shohei") == true
        }
        let descriptor = FetchDescriptor<JerseySighting>(predicate: predicate)
        let results = (try? context.fetch(descriptor)) ?? []

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.event, event)
    }

    func testSearchByPlayerLastName() {
        let event = TestDataFactory.makeEvent()
        context.insert(event)
        let sighting = TestDataFactory.makeSighting(firstName: "Shohei", lastName: "Ohtani", event: event)
        context.insert(sighting)
        try? context.save()

        let predicate = #Predicate<JerseySighting> { sighting in
            sighting.firstName?.localizedStandardContains("Ohtani") == true ||
            sighting.lastName?.localizedStandardContains("Ohtani") == true
        }
        let descriptor = FetchDescriptor<JerseySighting>(predicate: predicate)
        let results = (try? context.fetch(descriptor)) ?? []

        XCTAssertEqual(results.count, 1)
    }

    func testSearchByPlayerPartial() {
        let event = TestDataFactory.makeEvent()
        context.insert(event)
        let sighting = TestDataFactory.makeSighting(firstName: "Aaron", lastName: "Judge", event: event)
        context.insert(sighting)
        try? context.save()

        let predicate = #Predicate<JerseySighting> { sighting in
            sighting.firstName?.localizedStandardContains("judg") == true ||
            sighting.lastName?.localizedStandardContains("judg") == true
        }
        let descriptor = FetchDescriptor<JerseySighting>(predicate: predicate)
        let results = (try? context.fetch(descriptor)) ?? []

        XCTAssertEqual(results.count, 1)
    }

    func testSearchByPlayerNoMatch() {
        let event = TestDataFactory.makeEvent()
        context.insert(event)
        let sighting = TestDataFactory.makeSighting(firstName: "Mike", lastName: "Trout", event: event)
        context.insert(sighting)
        try? context.save()

        let predicate = #Predicate<JerseySighting> { sighting in
            sighting.firstName?.localizedStandardContains("Nonexistent") == true ||
            sighting.lastName?.localizedStandardContains("Nonexistent") == true
        }
        let descriptor = FetchDescriptor<JerseySighting>(predicate: predicate)
        let results = (try? context.fetch(descriptor)) ?? []

        XCTAssertEqual(results.count, 0)
    }

    func testSortsByDateDescending() {
        let earlyEvent = TestDataFactory.makeEvent(title: "AAA @ BBB", date: Date().addingTimeInterval(-86400))
        let lateEvent = TestDataFactory.makeEvent(title: "CCC @ DDD", date: Date())
        context.insert(earlyEvent)
        context.insert(lateEvent)
        try? context.save()

        let predicate = #Predicate<Event> { event in
            event.title.localizedStandardContains("@")
        }
        let descriptor = FetchDescriptor<Event>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        let results = (try? context.fetch(descriptor)) ?? []

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].title, "CCC @ DDD")
        XCTAssertEqual(results[1].title, "AAA @ BBB")
    }

    // MARK: - Filter tests

    func testFilterByLeagueReturnsTeamNames() {
        let mlbTeam = TestDataFactory.makeTeam(name: "NYY", sport: "mlb")
        let nbaTeam = TestDataFactory.makeTeam(name: "LAL", sport: "nba")
        context.insert(mlbTeam)
        context.insert(nbaTeam)
        try? context.save()

        let predicate = #Predicate<Team> { $0.sport == "mlb" }
        let names = (try? context.fetch(FetchDescriptor<Team>(predicate: predicate)))?.map { $0.name } ?? []

        XCTAssertEqual(names, ["NYY"])
    }

    func testFilterByLeagueNarrowsEvents() {
        let mlbTeam = TestDataFactory.makeTeam(name: "NYY", sport: "mlb")
        let nbaTeam = TestDataFactory.makeTeam(name: "LAL", sport: "nba")
        context.insert(mlbTeam)
        context.insert(nbaTeam)
        let mlbEvent = TestDataFactory.makeEvent(awayTeam: "NYY", homeTeam: "BOS")
        let nbaEvent = TestDataFactory.makeEvent(awayTeam: "LAL", homeTeam: "LAC")
        context.insert(mlbEvent)
        context.insert(nbaEvent)
        try? context.save()

        let league = "mlb"
        let teamNames = Set(
            (try? context.fetch(
                FetchDescriptor<Team>(predicate: #Predicate { $0.sport == league })
            ))?.map { $0.name } ?? []
        )
        let allEvents = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        let filtered = allEvents.filter {
            guard let away = $0.awayTeam, let home = $0.homeTeam else { return false }
            return teamNames.contains(away) || teamNames.contains(home)
        }

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.title, "NYY @ BOS")
    }

    func testFilterByWatchLocation() {
        let stadiumEvent = TestDataFactory.makeEvent(awayTeam: "NYY", homeTeam: "BOS")
        stadiumEvent.watchLocation = .stadium
        let tvEvent = TestDataFactory.makeEvent(awayTeam: "LAL", homeTeam: "LAC")
        tvEvent.watchLocation = .tv
        context.insert(stadiumEvent)
        context.insert(tvEvent)
        try? context.save()

        let allEvents = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        let stadiumEvents = allEvents.filter { $0.watchLocation == .stadium }
        let tvEvents = allEvents.filter { $0.watchLocation == .tv }

        XCTAssertEqual(stadiumEvents.count, 1)
        XCTAssertEqual(stadiumEvents.first?.awayTeam, "NYY")
        XCTAssertEqual(tvEvents.count, 1)
        XCTAssertEqual(tvEvents.first?.awayTeam, "LAL")
    }

    func testFilterByVenuePartialMatch() {
        let yankeeEvent = TestDataFactory.makeEvent(title: "NYY @ BOS", venue: "Yankee Stadium")
        let fenwayEvent = TestDataFactory.makeEvent(title: "BOS @ NYY", venue: "Fenway Park")
        context.insert(yankeeEvent)
        context.insert(fenwayEvent)
        try? context.save()

        let allEvents = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        let term = "yankee"
        let filtered = allEvents.filter { $0.venue?.lowercased().contains(term) == true }

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.venue, "Yankee Stadium")
    }

    func testFilterByDateRange() throws {
        let oldDate = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -10, to: Date()))
        let midDate = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -5, to: Date()))
        let recentDate = Date()
        let oldEvent = TestDataFactory.makeEvent(title: "Old", date: oldDate)
        let midEvent = TestDataFactory.makeEvent(title: "Mid", date: midDate)
        let recentEvent = TestDataFactory.makeEvent(title: "Recent", date: recentDate)
        context.insert(oldEvent)
        context.insert(midEvent)
        context.insert(recentEvent)
        try? context.save()

        let start = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -7, to: Date()))
        let end = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: Date()))
        let allEvents = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        let filtered = allEvents.filter { $0.date >= start && $0.date <= end }

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.title, "Mid")
    }

    func testFilterByPlayerNumber() {
        let event = TestDataFactory.makeEvent()
        context.insert(event)
        let sighting42 = TestDataFactory.makeSighting(firstName: "Jackie", number: "42", event: event)
        let sighting99 = TestDataFactory.makeSighting(firstName: "Wayne", number: "99", event: event)
        context.insert(sighting42)
        context.insert(sighting99)
        try? context.save()

        let predicate = #Predicate<JerseySighting> { sighting in
            sighting.playerNumber?.localizedStandardContains("42") == true
        }
        let results = (try? context.fetch(FetchDescriptor<JerseySighting>(predicate: predicate))) ?? []

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.firstName, "Jackie")
    }

    func testCombinedLeagueAndWatchLocationFilter() {
        let mlbTeam = TestDataFactory.makeTeam(name: "NYY", sport: "mlb")
        context.insert(mlbTeam)
        let stadiumMLB = TestDataFactory.makeEvent(awayTeam: "NYY", homeTeam: "BOS")
        stadiumMLB.watchLocation = .stadium
        let tvMLB = TestDataFactory.makeEvent(awayTeam: "HOU", homeTeam: "TEX")
        tvMLB.watchLocation = .tv
        let stadiumNBA = TestDataFactory.makeEvent(awayTeam: "LAL", homeTeam: "LAC")
        stadiumNBA.watchLocation = .stadium
        context.insert(stadiumMLB)
        context.insert(tvMLB)
        context.insert(stadiumNBA)
        try? context.save()

        let teamNames = Set(
            (try? context.fetch(
                FetchDescriptor<Team>(predicate: #Predicate { $0.sport == "mlb" })
            ))?.map { $0.name } ?? []
        )
        let allEvents = (try? context.fetch(FetchDescriptor<Event>())) ?? []
        let filtered = allEvents.filter {
            guard let away = $0.awayTeam, let home = $0.homeTeam else { return false }
            return (teamNames.contains(away) || teamNames.contains(home)) && $0.watchLocation == .stadium
        }

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.title, "NYY @ BOS")
    }

    func testSearchFiltersHasActiveFilters() {
        var filters = SearchFilters()
        XCTAssertFalse(filters.hasActiveFilters)
        filters.league = "mlb"
        XCTAssertTrue(filters.hasActiveFilters)
    }
}
