import XCTest
@testable import SeenAt

@MainActor
final class LiveActivityManagerTests: XCTestCase {
    private final class MockLiveActivityClient: LiveActivityClient {
        private var storedActiveEventIDs: [UUID]
        private var activeEventIDsReadWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
        var activeEventIDsReadCount = 0
        var requestedAttributes: SeenAtActivityAttributes?
        var requestedContentState: SeenAtActivityAttributes.ContentState?
        var updatedEventIDs: [UUID] = []
        var updatedContentStates: [UUID: SeenAtActivityAttributes.ContentState] = [:]
        var endedEventIDs: [UUID] = []
        var endAllCallCount = 0
        var requestCount = 0
        var blockRequests = false
        var requestStarted = false
        var requestStartWaiters: [CheckedContinuation<Void, Never>] = []
        var requestFinish: CheckedContinuation<Void, Never>?
        var blockUpdates = false
        var updateStarted = false
        var updateStartWaiters: [CheckedContinuation<Void, Never>] = []
        var updateFinish: CheckedContinuation<Void, Never>?

        init(activeEventIDs: [UUID] = []) {
            self.storedActiveEventIDs = activeEventIDs
        }

        var activeEventIDs: [UUID] {
            activeEventIDsReadCount += 1
            let readyWaiters = activeEventIDsReadWaiters.filter { $0.0 <= activeEventIDsReadCount }
            activeEventIDsReadWaiters.removeAll { $0.0 <= activeEventIDsReadCount }
            readyWaiters.forEach { $0.1.resume() }
            return storedActiveEventIDs
        }

        func request(
            attributes: SeenAtActivityAttributes,
            contentState: SeenAtActivityAttributes.ContentState
        ) async {
            requestCount += 1
            requestedAttributes = attributes
            requestedContentState = contentState
            if blockRequests {
                await withCheckedContinuation { continuation in
                    requestFinish = continuation
                    requestStarted = true
                    requestStartWaiters.forEach { $0.resume() }
                    requestStartWaiters.removeAll()
                }
            } else {
                requestStarted = true
                requestStartWaiters.forEach { $0.resume() }
                requestStartWaiters.removeAll()
            }
            if !storedActiveEventIDs.contains(attributes.eventID) {
                storedActiveEventIDs.append(attributes.eventID)
            }
        }

        func waitUntilRequestStarts() async {
            if requestStarted { return }
            await withCheckedContinuation { continuation in
                requestStartWaiters.append(continuation)
            }
        }

        func finishRequest() {
            requestFinish?.resume()
            requestFinish = nil
        }

        func waitUntilActiveEventIDsRead(_ count: Int) async {
            if activeEventIDsReadCount >= count { return }
            await withCheckedContinuation { continuation in
                activeEventIDsReadWaiters.append((count, continuation))
            }
        }

        func update(eventID: UUID, contentState: SeenAtActivityAttributes.ContentState) async {
            if blockUpdates {
                await withCheckedContinuation { continuation in
                    updateFinish = continuation
                    updateStarted = true
                    updateStartWaiters.forEach { $0.resume() }
                    updateStartWaiters.removeAll()
                }
            }
            updatedEventIDs.append(eventID)
            updatedContentStates[eventID] = contentState
        }

        func waitUntilUpdateStarts() async {
            if updateStarted { return }
            await withCheckedContinuation { continuation in
                updateStartWaiters.append(continuation)
            }
        }

        func finishUpdate() {
            updateFinish?.resume()
            updateFinish = nil
        }

        func end(eventID: UUID) async {
            endedEventIDs.append(eventID)
            storedActiveEventIDs.removeAll { $0 == eventID }
            requestFinish?.resume()
            requestFinish = nil
            updateFinish?.resume()
            updateFinish = nil
        }

        func endAll() async {
            endAllCallCount += 1
            storedActiveEventIDs.removeAll()
            requestFinish?.resume()
            requestFinish = nil
            updateFinish?.resume()
            updateFinish = nil
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
        client.blockRequests = true

        let firstStart = Task { @MainActor in
            await LiveActivityManager.startOrUpdate(for: event, teams: [], client: client)
        }
        await client.waitUntilRequestStarts()
        let secondStart = Task { @MainActor in
            await LiveActivityManager.startOrUpdate(for: event, teams: [], client: client)
        }
        await client.waitUntilActiveEventIDsRead(2)
        client.finishRequest()
        await firstStart.value
        await secondStart.value

        XCTAssertEqual(client.requestCount, 1)
        XCTAssertEqual(client.activeEventIDs, [event.id])
    }

    func testConcurrentStartOrUpdateAppliesLatestContentState() async {
        let event = TestDataFactory.makeEvent(awayTeam: "Away", homeTeam: "Home")
        let client = MockLiveActivityClient()
        client.blockRequests = true

        let firstStart = Task { @MainActor in
            await LiveActivityManager.startOrUpdate(for: event, teams: [], client: client)
        }
        await client.waitUntilRequestStarts()

        let sighting = TestDataFactory.makeSighting(firstName: "Latest", event: event)
        event.sightings = [sighting]
        let secondStart = Task { @MainActor in
            await LiveActivityManager.startOrUpdate(for: event, teams: [], client: client)
        }
        await client.waitUntilActiveEventIDsRead(2)
        client.finishRequest()
        await firstStart.value
        await secondStart.value

        XCTAssertEqual(client.requestCount, 1)
        XCTAssertEqual(client.updatedContentStates[event.id]?.jerseyCount, 1)
        XCTAssertEqual(client.updatedContentStates[event.id]?.mostRecentJerseyName, "Latest")
    }

    func testThreeConcurrentStartsApplyNewestContentState() async {
        let event = TestDataFactory.makeEvent(awayTeam: "Away", homeTeam: "Home")
        let client = MockLiveActivityClient()
        client.blockRequests = true

        let firstStart = Task { @MainActor in
            await LiveActivityManager.startOrUpdate(for: event, teams: [], client: client)
        }
        await client.waitUntilRequestStarts()

        let secondSighting = TestDataFactory.makeSighting(firstName: "Second", event: event)
        event.sightings = [secondSighting]
        let secondStart = Task { @MainActor in
            await LiveActivityManager.startOrUpdate(for: event, teams: [], client: client)
        }
        await client.waitUntilActiveEventIDsRead(2)

        let thirdSighting = TestDataFactory.makeSighting(firstName: "Third", event: event)
        event.sightings = [secondSighting, thirdSighting]
        let thirdStart = Task { @MainActor in
            await LiveActivityManager.startOrUpdate(for: event, teams: [], client: client)
        }
        await client.waitUntilActiveEventIDsRead(3)

        client.finishRequest()
        await firstStart.value
        await secondStart.value
        await thirdStart.value

        XCTAssertEqual(client.updatedContentStates[event.id]?.jerseyCount, 2)
        XCTAssertEqual(client.updatedContentStates[event.id]?.mostRecentJerseyName, "Third")
    }

    func testConcurrentActiveUpdatesApplyNewestContentState() async {
        let event = TestDataFactory.makeEvent(awayTeam: "Away", homeTeam: "Home")
        let client = MockLiveActivityClient(activeEventIDs: [event.id])
        client.blockUpdates = true

        let firstUpdate = Task { @MainActor in
            await LiveActivityManager.startOrUpdate(for: event, teams: [], client: client)
        }
        await client.waitUntilUpdateStarts()

        let sighting = TestDataFactory.makeSighting(firstName: "Newest", event: event)
        event.sightings = [sighting]
        let secondUpdate = Task { @MainActor in
            await LiveActivityManager.startOrUpdate(for: event, teams: [], client: client)
        }
        await client.waitUntilActiveEventIDsRead(2)

        client.blockUpdates = false
        client.finishUpdate()
        await firstUpdate.value
        await secondUpdate.value

        XCTAssertEqual(client.updatedContentStates[event.id]?.jerseyCount, 1)
        XCTAssertEqual(client.updatedContentStates[event.id]?.mostRecentJerseyName, "Newest")
    }

    func testEndInvalidatesPendingStart() async {
        let event = TestDataFactory.makeEvent(awayTeam: "Away", homeTeam: "Home")
        let client = MockLiveActivityClient()
        client.blockRequests = true

        let start = Task { @MainActor in
            await LiveActivityManager.startOrUpdate(for: event, teams: [], client: client)
        }
        await client.waitUntilRequestStarts()

        await LiveActivityManager.end(for: event.id, client: client)
        client.finishRequest()
        await start.value

        XCTAssertTrue(client.activeEventIDs.isEmpty)
        XCTAssertGreaterThanOrEqual(client.endedEventIDs.count, 1)
    }

    func testEndStaleActivitiesInvalidatesPendingStart() async {
        let event = TestDataFactory.makeEvent(awayTeam: "Away", homeTeam: "Home", date: .now)
        let client = MockLiveActivityClient()
        client.blockRequests = true

        let start = Task { @MainActor in
            await LiveActivityManager.startOrUpdate(for: event, teams: [], client: client)
        }
        await client.waitUntilRequestStarts()

        await LiveActivityManager.endStaleActivities(for: [], client: client)
        client.finishRequest()
        await start.value

        XCTAssertTrue(client.activeEventIDs.isEmpty)
        XCTAssertGreaterThanOrEqual(client.endedEventIDs.count, 1)
    }

    func testEndWaitsForInvalidatedStartBeforeReplacementBegins() async {
        let event = TestDataFactory.makeEvent(awayTeam: "Away", homeTeam: "Home")
        let client = MockLiveActivityClient()
        client.blockRequests = true

        let originalStart = Task { @MainActor in
            await LiveActivityManager.startOrUpdate(for: event, teams: [], client: client)
        }
        await client.waitUntilRequestStarts()

        await LiveActivityManager.end(for: event.id, client: client)
        client.blockRequests = false
        let replacementStart = Task { @MainActor in
            await LiveActivityManager.startOrUpdate(for: event, teams: [], client: client)
        }
        client.finishRequest()
        await originalStart.value
        await replacementStart.value

        XCTAssertEqual(client.requestCount, 2)
        XCTAssertEqual(client.activeEventIDs, [event.id])
    }

    func testEndAllPreventsWaitingStartFromRestarting() async {
        let event = TestDataFactory.makeEvent(awayTeam: "Away", homeTeam: "Home")
        let client = MockLiveActivityClient()
        client.blockRequests = true

        let originalStart = Task { @MainActor in
            await LiveActivityManager.startOrUpdate(for: event, teams: [], client: client)
        }
        await client.waitUntilRequestStarts()
        let waitingStart = Task { @MainActor in
            await LiveActivityManager.startOrUpdate(for: event, teams: [], client: client)
        }
        await client.waitUntilActiveEventIDsRead(2)

        await LiveActivityManager.endAll(client: client)
        client.finishRequest()
        await originalStart.value
        await waitingStart.value

        XCTAssertEqual(client.endAllCallCount, 1)
        XCTAssertTrue(client.activeEventIDs.isEmpty)
    }

    func testEndStaleActivitiesPreventsWaitingStartFromRestarting() async {
        let event = TestDataFactory.makeEvent(awayTeam: "Away", homeTeam: "Home")
        let client = MockLiveActivityClient()
        client.blockRequests = true

        let originalStart = Task { @MainActor in
            await LiveActivityManager.startOrUpdate(for: event, teams: [], client: client)
        }
        await client.waitUntilRequestStarts()
        let waitingStart = Task { @MainActor in
            await LiveActivityManager.startOrUpdate(for: event, teams: [], client: client)
        }
        await client.waitUntilActiveEventIDsRead(2)

        await LiveActivityManager.endStaleActivities(for: [], client: client)
        client.finishRequest()
        await originalStart.value
        await waitingStart.value

        XCTAssertTrue(client.activeEventIDs.isEmpty)
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
