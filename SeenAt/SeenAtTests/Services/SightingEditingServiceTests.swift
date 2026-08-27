import XCTest
import SwiftData
@testable import SeenAt

@MainActor
final class SightingEditingServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var event: Event!
    private var homeTeam: Team!
    private var awayTeam: Team!

    override func setUp() {
        super.setUp()
        container = TestModelContainer.create()
        context = container.mainContext
        event = TestDataFactory.makeEvent()
        homeTeam = TestDataFactory.makeTeam(name: "Home Team")
        awayTeam = TestDataFactory.makeTeam(name: "Away Team")
        context.insert(event)
        context.insert(homeTeam)
        context.insert(awayTeam)
        try? context.save()
    }

    override func tearDown() {
        awayTeam = nil
        homeTeam = nil
        event = nil
        context = nil
        container = nil
        super.tearDown()
    }

    func testUpdateChangesOneSightingAndPersistsPhotoRemoval() throws {
        let sighting = TestDataFactory.makeSighting(
            team: homeTeam,
            firstName: "Jon",
            lastName: "Smyth",
            number: "7",
            event: event
        )
        sighting.photoData = Data([0x01, 0x02])
        context.insert(sighting)
        try context.save()

        XCTAssertTrue(SightingEditingService.update(
            sighting,
            team: awayTeam,
            firstName: "John",
            lastName: "Smith",
            playerNumber: "17",
            photoData: nil,
            context: context
        ))

        let saved = try XCTUnwrap(context.fetch(FetchDescriptor<JerseySighting>()).first)
        XCTAssertEqual(saved.team?.id, awayTeam.id)
        XCTAssertEqual(saved.firstName, "John")
        XCTAssertEqual(saved.lastName, "Smith")
        XCTAssertEqual(saved.playerNumber, "17")
        XCTAssertNil(saved.photoData)
    }

    func testDeleteRemovesOnlySelectedSighting() throws {
        let first = TestDataFactory.makeSighting(team: homeTeam, firstName: "John", lastName: "Doe", event: event)
        let second = TestDataFactory.makeSighting(team: homeTeam, firstName: "John", lastName: "Doe", event: event)
        context.insert(first)
        context.insert(second)
        try context.save()

        XCTAssertTrue(SightingEditingService.delete(first, context: context))

        let remaining = try context.fetch(FetchDescriptor<JerseySighting>())
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.persistentModelID, second.persistentModelID)
    }

    func testUpdateRejectsFutureEvent() {
        event.date = Calendar.current.date(byAdding: .day, value: 1, to: .now)!
        let sighting = TestDataFactory.makeSighting(team: homeTeam, firstName: "John", event: event)
        context.insert(sighting)

        XCTAssertFalse(SightingEditingService.update(
            sighting,
            team: awayTeam,
            firstName: "Jane",
            lastName: nil,
            playerNumber: nil,
            photoData: nil,
            context: context
        ))
        XCTAssertEqual(sighting.team?.id, homeTeam.id)
        XCTAssertEqual(sighting.firstName, "John")
    }
}
