import XCTest
@testable import SeenAt

@MainActor
final class LiveActivityManagerTests: XCTestCase {
    private final class MockLiveActivityClient: LiveActivityClient {
        var activeEventIDs: [UUID]
        var requestedAttributes: SeenAtActivityAttributes?
        var requestedContentState: SeenAtActivityAttributes.ContentState?
        var updatedEventIDs: [UUID] = []
        var updatedContentStates: [UUID: SeenAtActivityAttributes.ContentState] = [:]
        var endedEventIDs: [UUID] = []
        var endAllCallCount = 0
        var requestCount = 0

        init(activeEventIDs: [UUID] = []) {
            self.activeEventIDs = activeEventIDs
        }

        func request(
            attributes: SeenAtActivityAttributes,
            contentState: SeenAtActivityAttributes.ContentState
        ) async {
            requestCount += 1
            requestedAttributes = attributes
            requestedContentState = contentState
            try? await Task.sleep(nanoseconds: 10_000_000)
            if !activeEventIDs.contains(attributes.eventID) {
                activeEventIDs.append(attributes.eventID)
            }
        }

        func update(eventID: UUID, contentState: SeenAtActivityAttributes.ContentState) async {
            updatedEventIDs.append(eventID)
            updatedContentStates[eventID] = contentState
        }

        func end(eventID: UUID) async {
            endedEventIDs.append(eventID)
        }

        func endAll() async {
            endAllCallCount += 1
        }
    }

    func testFindBestTodayEventReturnsNilForEmptyEvents() {
        XCTAssertNil(LiveActivityManager.findBestTodayEvent(in: []))
    }

    func testFindBestTodayEventIgnoresEventsOutsideToday() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: .now)!

        let events = [
            TestDataFactory.makeEvent(date: yesterday),
            TestDataFactory.makeEvent(date: tomorrow),
        ]

        XCTAssertNil(LiveActivityManager.findBestTodayEvent(in: events))
    }

    func testFindBestTodayEventReturnsOnlyTodayEvent() {
        let event = TestDataFactory.makeEvent(date: .now)

        XCTAssertEqual(LiveActivityManager.findBestTodayEvent(in: [event])?.id, event.id)
    }

    func testFindBestTodayEventUsesLatestSightingTimestamp() {
        let older = TestDataFactory.makeEvent(date: .now)
        older.createdAt = .now
        let newer = TestDataFactory.makeEvent(date: .now)
        newer.createdAt = older.createdAt.addingTimeInterval(-60)

        let sighting = TestDataFactory.makeSighting(firstName: "Recent")
        sighting.timestamp = older.createdAt.addingTimeInterval(60)
        sighting.event = older
        older.sightings = [sighting]

        XCTAssertEqual(
            LiveActivityManager.findBestTodayEvent(in: [older, newer])?.id,
            older.id
        )
    }

    func testFindBestTodayEventUsesCreatedAtWhenThereAreNoSightings() {
        let older = TestDataFactory.makeEvent(date: .now)
        older.createdAt = .now.addingTimeInterval(-60)
        let newer = TestDataFactory.makeEvent(date: .now)
        newer.createdAt = .now

        XCTAssertEqual(
            LiveActivityManager.findBestTodayEvent(in: [older, newer])?.id,
            newer.id
        )
    }

    func testStartOrUpdateRequestsActivityWhenEventIsNotActive() async {
        let event = TestDataFactory.makeEvent(awayTeam: "Away", homeTeam: "Home")
        let awayTeam = TestDataFactory.makeTeam(name: "Away", secondaryHex: "away-color")
        let homeTeam = TestDataFactory.makeTeam(name: "Home", primaryHex: "home-color")
        let sighting = TestDataFactory.makeSighting(firstName: "Jane", lastName: "Doe", event: event)
        event.sightings = [sighting]
        let client = MockLiveActivityClient()

        await LiveActivityManager.startOrUpdate(for: event, teams: [awayTeam, homeTeam], client: client)

        XCTAssertEqual(client.requestedAttributes?.eventID, event.id)
        XCTAssertEqual(client.requestedAttributes?.homeTeamColor, "home-color")
        XCTAssertEqual(client.requestedAttributes?.awayTeamColor, "away-color")
        XCTAssertEqual(client.requestedContentState?.jerseyCount, 1)
        XCTAssertEqual(client.requestedContentState?.mostRecentJerseyName, "Jane Doe")
        XCTAssertTrue(client.updatedEventIDs.isEmpty)
    }

    func testStartOrUpdateUpdatesActivityWhenEventIsActive() async {
        let event = TestDataFactory.makeEvent(awayTeam: "Away", homeTeam: "Home")
        let client = MockLiveActivityClient(activeEventIDs: [event.id])

        await LiveActivityManager.startOrUpdate(for: event, teams: [], client: client)

        XCTAssertEqual(client.updatedEventIDs, [event.id])
        XCTAssertEqual(client.updatedContentStates[event.id]?.jerseyCount, 0)
        XCTAssertNil(client.requestedAttributes)
    }

    func testConcurrentStartOrUpdateRequestsOnlyOneActivity() async {
        let event = TestDataFactory.makeEvent(awayTeam: "Away", homeTeam: "Home")
        let client = MockLiveActivityClient()

        let firstStart = Task { @MainActor in
            await LiveActivityManager.startOrUpdate(for: event, teams: [], client: client)
        }
        let secondStart = Task { @MainActor in
            await LiveActivityManager.startOrUpdate(for: event, teams: [], client: client)
        }
        await firstStart.value
        await secondStart.value

        XCTAssertEqual(client.requestCount, 1)
        XCTAssertEqual(client.activeEventIDs, [event.id])
    }

    func testEndDelegatesToClient() async {
        let eventID = UUID()
        let client = MockLiveActivityClient()

        await LiveActivityManager.end(for: eventID, client: client)

        XCTAssertEqual(client.endedEventIDs, [eventID])
    }

    func testEndAllDelegatesToClient() async {
        let client = MockLiveActivityClient()

        await LiveActivityManager.endAll(client: client)

        XCTAssertEqual(client.endAllCallCount, 1)
    }

    func testEndStaleActivitiesEndsOnlyInactiveEventIDs() async {
        let todayEvent = TestDataFactory.makeEvent(date: .now)
        let staleID = UUID()
        let client = MockLiveActivityClient(activeEventIDs: [todayEvent.id, staleID])

        await LiveActivityManager.endStaleActivities(for: [todayEvent], client: client)

        XCTAssertEqual(client.endedEventIDs, [staleID])
    }
}
