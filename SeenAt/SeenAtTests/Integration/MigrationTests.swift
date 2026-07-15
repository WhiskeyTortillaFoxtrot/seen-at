import XCTest
@testable import SeenAt
import SwiftData

@MainActor
final class MigrationTests: XCTestCase {
    private func createV1Store(at url: URL) throws {
        let config = ModelConfiguration(url: url)
        let container = try ModelContainer(
            for: SeenAtSchemaV1.Team.self, SeenAtSchemaV1.Event.self, SeenAtSchemaV1.JerseySighting.self,
            configurations: config
        )
        let context = container.mainContext

        let team = SeenAtSchemaV1.Team(
            name: "New York Yankees",
            abbreviation: "NYY",
            sport: "mlb",
            primaryColorHex: "#A71930",
            secondaryColorHex: "#041E42"
        )
        context.insert(team)

        let event1 = SeenAtSchemaV1.Event(title: "Yankees @ Red Sox", date: Date())
        context.insert(event1)

        let sighting = SeenAtSchemaV1.JerseySighting(team: team, firstName: "Derek", playerNumber: "2", event: event1)
        context.insert(sighting)

        let event2 = SeenAtSchemaV1.Event(title: "Cubs @ Cardinals", date: Date())
        context.insert(event2)

        let event3 = SeenAtSchemaV1.Event(title: "No teams here", date: Date())
        context.insert(event3)

        let event4 = SeenAtSchemaV1.Event(title: "  A  @  B  ", date: Date())
        context.insert(event4)

        let event5 = SeenAtSchemaV1.Event(title: "A @ B @ C", date: Date())
        context.insert(event5)

        let event6 = SeenAtSchemaV1.Event(title: " @ Red Sox", date: Date())
        context.insert(event6)

        try context.save()
    }

    private func cleanupSidecars(at url: URL) {
        let base = url.deletingPathExtension()
        for suffix in ["", "-wal", "-shm"] {
            let file = base.appendingPathExtension("sqlite\(suffix)")
            try? FileManager.default.removeItem(at: file)
        }
    }

    func testV1ToV2MigrationPopulatesAwayAndHomeTeams() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("migration_\(UUID().uuidString).sqlite")
        defer { cleanupSidecars(at: url) }

        try createV1Store(at: url)

        let config = ModelConfiguration(url: url)
        let container = try ModelContainer(
            for: Team.self, Event.self, JerseySighting.self,
            migrationPlan: SeenAtMigrationPlan.self,
            configurations: config
        )

        let descriptor = FetchDescriptor<Event>(sortBy: [SortDescriptor(\.title)])
        let events = try container.mainContext.fetch(descriptor)

        XCTAssertEqual(events.count, 6)

        let yankees = events.first { $0.title == "Yankees @ Red Sox" }
        XCTAssertEqual(yankees?.awayTeam, "Yankees")
        XCTAssertEqual(yankees?.homeTeam, "Red Sox")

        let cubs = events.first { $0.title == "Cubs @ Cardinals" }
        XCTAssertEqual(cubs?.awayTeam, "Cubs")
        XCTAssertEqual(cubs?.homeTeam, "Cardinals")

        let noTeams = events.first { $0.title == "No teams here" }
        XCTAssertNil(noTeams?.awayTeam)
        XCTAssertNil(noTeams?.homeTeam)

        let whitespace = events.first { $0.title == "  A  @  B  " }
        XCTAssertEqual(whitespace?.awayTeam, "A")
        XCTAssertEqual(whitespace?.homeTeam, "B")

        let multiSeparator = events.first { $0.title == "A @ B @ C" }
        XCTAssertNil(multiSeparator?.awayTeam)
        XCTAssertNil(multiSeparator?.homeTeam)

        let emptyAway = events.first { $0.title == " @ Red Sox" }
        XCTAssertNil(emptyAway?.awayTeam)
        XCTAssertNil(emptyAway?.homeTeam)

        // id is preserved from V1 (not the zero UUID)
        for event in events {
            XCTAssertNotEqual(event.id.uuidString, "00000000-0000-0000-0000-000000000000")
        }

        // Verify inverse relationships are preserved
        let sightingDescriptor = FetchDescriptor<JerseySighting>()
        let sightings = try container.mainContext.fetch(sightingDescriptor)
        XCTAssertEqual(sightings.count, 1)
        XCTAssertEqual(sightings.first?.event?.title, "Yankees @ Red Sox")
        XCTAssertEqual(sightings.first?.team?.name, "New York Yankees")
    }
}
