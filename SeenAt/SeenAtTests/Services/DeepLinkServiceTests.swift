import XCTest
@testable import SeenAt
import SwiftData

@MainActor
final class DeepLinkServiceTests: XCTestCase {
    func testFetchEventReturnsMatchingEvent() throws {
        let container = TestModelContainer.create()
        let context = container.mainContext
        let event = TestDataFactory.makeEvent()
        context.insert(event)
        try context.save()

        let fetched = try DeepLinkService.fetchEvent(by: event.id, context: context)

        XCTAssertEqual(fetched?.id, event.id)
    }

    func testResolveReturnsOpenEventForMatchingID() throws {
        let container = TestModelContainer.create()
        let context = container.mainContext
        let event = TestDataFactory.makeEvent()
        context.insert(event)
        try context.save()

        let resolution = try DeepLinkService.resolve(eventID: event.id, context: context)

        guard case .openEvent(let resolvedEvent, let selectedTab) = resolution else {
            return XCTFail("Expected an open-event resolution")
        }
        XCTAssertEqual(resolvedEvent.id, event.id)
        XCTAssertEqual(selectedTab, 0)
    }

    func testNavigationStateAppliesSuccessfulResolution() {
        let event = TestDataFactory.makeEvent()
        let deepLinkID = UUID()
        var state = DeepLinkNavigationState(
            eventToTrack: nil,
            eventToSummarize: nil,
            selectedTab: 3,
            deepLinkDestination: .liveTracking(deepLinkID)
        )

        state.apply(.openEvent(event, selectedTab: 0), as: .liveTracking(deepLinkID))

        XCTAssertEqual(state.eventToTrack?.id, event.id)
        XCTAssertEqual(state.selectedTab, 0)
        XCTAssertNil(state.deepLinkDestination)
        XCTAssertFalse(state.shouldReportError)
    }

    func testNavigationStateRoutesEventSummarySeparatelyFromTracking() {
        let event = TestDataFactory.makeEvent()
        let deepLinkID = event.id
        var state = DeepLinkNavigationState(
            eventToTrack: nil,
            eventToSummarize: nil,
            selectedTab: 2,
            deepLinkDestination: .eventSummary(deepLinkID)
        )

        state.apply(.openEvent(event, selectedTab: 0), as: .eventSummary(deepLinkID))

        XCTAssertNil(state.eventToTrack)
        XCTAssertEqual(state.eventToSummarize?.id, event.id)
        XCTAssertEqual(state.selectedTab, 0)
        XCTAssertNil(state.deepLinkDestination)
    }

    func testNavigationStateOpensStats() {
        var state = DeepLinkNavigationState(
            eventToTrack: nil,
            eventToSummarize: nil,
            selectedTab: 0,
            deepLinkDestination: .stats
        )

        state.openStats()

        XCTAssertEqual(state.selectedTab, 1)
        XCTAssertNil(state.deepLinkDestination)
        XCTAssertFalse(state.shouldReportError)
    }

    func testFetchEventReturnsNilForUnknownID() throws {
        let container = TestModelContainer.create()
        let context = container.mainContext

        XCTAssertNil(try DeepLinkService.fetchEvent(by: UUID(), context: context))
    }

    func testResolveReturnsNotFoundForUnknownID() throws {
        let container = TestModelContainer.create()
        let context = container.mainContext

        guard case .notFound = try DeepLinkService.resolve(eventID: UUID(), context: context) else {
            return XCTFail("Expected a not-found resolution")
        }
    }

    func testNavigationStateReportsNotFoundWithoutClearingNavigation() {
        let deepLinkID = UUID()
        var state = DeepLinkNavigationState(
            eventToTrack: nil,
            eventToSummarize: nil,
            selectedTab: 2,
            deepLinkDestination: .liveTracking(deepLinkID)
        )

        state.apply(.notFound, as: .liveTracking(deepLinkID))

        XCTAssertEqual(state.selectedTab, 2)
        XCTAssertEqual(state.deepLinkDestination, .liveTracking(deepLinkID))
        XCTAssertTrue(state.shouldReportError)
    }

    func testFetchEventReturnsNilForEmptyStore() throws {
        let container = TestModelContainer.create()
        let context = container.mainContext

        XCTAssertNil(try DeepLinkService.fetchEvent(by: UUID(), context: context))
    }

    func testFetchEventSelectsRequestedEventFromMultipleEvents() throws {
        let container = TestModelContainer.create()
        let context = container.mainContext
        let first = TestDataFactory.makeEvent(title: "First")
        let second = TestDataFactory.makeEvent(title: "Second")
        context.insert(first)
        context.insert(second)
        try context.save()

        let fetched = try DeepLinkService.fetchEvent(by: second.id, context: context)

        XCTAssertEqual(fetched?.title, "Second")
    }
}
