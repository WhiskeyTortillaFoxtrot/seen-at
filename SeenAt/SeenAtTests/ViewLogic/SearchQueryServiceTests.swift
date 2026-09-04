import XCTest
import SwiftData
@testable import SeenAt

/// Exercises the production search pipeline (SearchQueryService) end to end, which the
/// predicate-level SearchViewTests cannot: an empty candidate set from a text or number
/// query must yield zero results rather than every event.
@MainActor
final class SearchQueryServiceTests: XCTestCase {
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

    private func seedData() {
        let yankees = TestDataFactory.makeTeam(name: "New York Yankees", sport: "mlb")
        let bruins = TestDataFactory.makeTeam(name: "Boston Bruins", sport: "nhl")
        context.insert(yankees)
        context.insert(bruins)

        let baseballEvent = TestDataFactory.makeEvent(
            awayTeam: "New York Yankees",
            homeTeam: "Boston Red Sox",
            venue: "Yankee Stadium"
        )
        context.insert(baseballEvent)

        let hockeyEvent = TestDataFactory.makeEvent(
            awayTeam: "Boston Bruins",
            homeTeam: "Montreal Canadiens",
            venue: "TD Garden"
        )
        hockeyEvent.watchLocation = .tv
        context.insert(hockeyEvent)

        let baseballSighting = TestDataFactory.makeSighting(
            team: yankees,
            firstName: "Derek",
            lastName: "Jeter",
            number: "2",
            event: baseballEvent
        )
        context.insert(baseballSighting)

        let hockeySighting = TestDataFactory.makeSighting(
            team: bruins,
            firstName: "Patrice",
            lastName: "Bergeron",
            number: "37",
            event: hockeyEvent
        )
        context.insert(hockeySighting)

        try? context.save()
    }

    func testTextQueryThatMatchesNothingReturnsNoEvents() {
        seedData()

        let outcome = SearchQueryService.search(term: "Nonexistent", numberTerm: "", filters: SearchFilters(), context: context)

        XCTAssertTrue(outcome.events.isEmpty, "A text query matching nothing must not fall back to every event")
    }

    func testTextQueryThatMatchesNothingWithFiltersReturnsNoEvents() {
        seedData()

        var filters = SearchFilters()
        filters.watchLocation = .stadium

        let outcome = SearchQueryService.search(term: "Nonexistent", numberTerm: "", filters: filters, context: context)

        XCTAssertTrue(outcome.events.isEmpty, "A text query matching nothing must not fall back to filter-only results")
    }

    func testNumberQueryThatMatchesNothingReturnsNoEvents() {
        seedData()

        let outcome = SearchQueryService.search(term: "", numberTerm: "999", filters: SearchFilters(), context: context)

        XCTAssertTrue(outcome.events.isEmpty, "A number query matching nothing must not fall back to every event")
    }

    func testNumberQueryThatMatchesNothingWithFiltersReturnsNoEvents() {
        seedData()

        var filters = SearchFilters()
        filters.league = "mlb"

        let outcome = SearchQueryService.search(term: "", numberTerm: "999", filters: filters, context: context)

        XCTAssertTrue(outcome.events.isEmpty)
    }

    func testFilterOnlySearchReturnsAllMatchingEvents() {
        seedData()

        var filters = SearchFilters()
        filters.watchLocation = .tv

        let outcome = SearchQueryService.search(term: "", numberTerm: "", filters: filters, context: context)

        XCTAssertEqual(outcome.events.count, 1)
        XCTAssertEqual(outcome.events.first?.venue, "TD Garden")
        XCTAssertTrue(outcome.matchedEventIDs.isEmpty, "Filter-only results are not text matches")
    }

    func testTextQueryMatchingTitleReturnsEventAsMatch() {
        seedData()

        let outcome = SearchQueryService.search(term: "Yankees", numberTerm: "", filters: SearchFilters(), context: context)

        XCTAssertEqual(outcome.events.count, 1)
        XCTAssertEqual(outcome.events.first?.venue, "Yankee Stadium")
        XCTAssertTrue(outcome.matchedEventIDs.contains(outcome.events[0].id))
    }

    func testTextQueryMatchingPlayerNameReturnsEventAsMatch() {
        seedData()

        let outcome = SearchQueryService.search(term: "Bergeron", numberTerm: "", filters: SearchFilters(), context: context)

        XCTAssertEqual(outcome.events.count, 1)
        XCTAssertEqual(outcome.events.first?.venue, "TD Garden")
    }

    func testNumberQueryMatchesSightingEvent() {
        seedData()

        let outcome = SearchQueryService.search(term: "", numberTerm: "37", filters: SearchFilters(), context: context)

        XCTAssertEqual(outcome.events.count, 1)
        XCTAssertEqual(outcome.events.first?.venue, "TD Garden")
        XCTAssertTrue(outcome.matchedEventIDs.contains(outcome.events[0].id))
    }

    func testLeagueFilterNarrowsTextMatches() {
        seedData()

        var filters = SearchFilters()
        filters.league = "mlb"

        // Both events mention "Boston" in their titles; only the baseball event belongs
        // to a team seeded with sport "mlb".
        let outcome = SearchQueryService.search(term: "Boston", numberTerm: "", filters: filters, context: context)

        XCTAssertEqual(outcome.events.count, 1)
        XCTAssertEqual(outcome.events.first?.venue, "Yankee Stadium")
    }

    func testNoQueryAndNoFiltersReturnsNothing() {
        seedData()

        let outcome = SearchQueryService.search(term: "", numberTerm: "", filters: SearchFilters(), context: context)

        XCTAssertTrue(outcome.events.isEmpty)
    }

    func testActiveFilterCountStartsAtZero() {
        let filters = SearchFilters()
        XCTAssertEqual(filters.activeFilterCount, 0)
        XCTAssertFalse(filters.hasActiveFilters)
    }

    func testActiveFilterCountCountsEachFilterOnce() {
        var filters = SearchFilters()
        filters.league = "mlb"
        filters.watchLocation = .tv
        filters.venueQuery = "Garden"
        filters.dateRangeActive = true
        filters.playerNumber = "37"

        XCTAssertEqual(filters.activeFilterCount, 5)
        XCTAssertTrue(filters.hasActiveFilters)
    }

    func testActiveFilterCountIgnoresBlankText() {
        var filters = SearchFilters()
        filters.venueQuery = "   "
        filters.playerNumber = "  "

        XCTAssertEqual(filters.activeFilterCount, 0)
        XCTAssertFalse(filters.hasActiveFilters)
    }

    func testDateRangeIncludesTheEntireSelectedEndDay() throws {
        let calendar = Calendar(identifier: .gregorian)
        let selectedDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 3)))
        let evening = try XCTUnwrap(calendar.date(byAdding: .hour, value: 20, to: selectedDay))
        let nextDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: selectedDay))
        let selectedEvent = TestDataFactory.makeEvent(title: "Selected day", date: evening)
        let excludedEvent = TestDataFactory.makeEvent(title: "Next day", date: nextDay)
        context.insert(selectedEvent)
        context.insert(excludedEvent)
        try context.save()

        var filters = SearchFilters()
        filters.dateRangeActive = true
        filters.dateRangeStart = selectedDay
        filters.dateRangeEnd = selectedDay

        let outcome = SearchQueryService.search(term: "", numberTerm: "", filters: filters, context: context)

        XCTAssertEqual(outcome.events.map(\.title), ["Selected day"])
    }
}
