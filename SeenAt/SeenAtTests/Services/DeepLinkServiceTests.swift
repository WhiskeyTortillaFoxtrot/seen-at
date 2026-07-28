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

        guard case .openEvent(let resolvedEvent) = resolution else {
            return XCTFail("Expected an open-event resolution")
        }
        XCTAssertEqual(resolvedEvent.id, event.id)
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
