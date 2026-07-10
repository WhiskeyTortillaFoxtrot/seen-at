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
}
