import Foundation
import SwiftData

// MARK: - V1 (Original — Event without awayTeam/homeTeam)

enum SeenAtSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [Team.self, Event.self, JerseySighting.self] }

    @Model
    final class Team {
        @Attribute(.unique) var name: String
        var abbreviation: String
        var sport: String
        var isBuiltIn: Bool
        var primaryColorHex: String
        var secondaryColorHex: String
        var logoData: Data?

        @Relationship(deleteRule: .cascade)
        var sightings: [JerseySighting] = []

        init(name: String, abbreviation: String, sport: String = "mlb", isBuiltIn: Bool = false, primaryColorHex: String, secondaryColorHex: String, logoData: Data? = nil) {
            self.name = name
            self.abbreviation = abbreviation
            self.sport = sport
            self.isBuiltIn = isBuiltIn
            self.primaryColorHex = primaryColorHex
            self.secondaryColorHex = secondaryColorHex
            self.logoData = logoData
        }
    }

    @Model
    final class Event {
        @Attribute(.unique) var id: UUID = UUID()
        var title: String
        var date: Date
        var venue: String?
        var gameUrl: String?
        var notes: String?
        var watchLocation: WatchLocation?
        var createdAt: Date

        @Relationship(deleteRule: .cascade)
        var sightings: [JerseySighting] = []

        init(title: String, date: Date, venue: String? = nil, gameUrl: String? = nil, notes: String? = nil, watchLocation: WatchLocation? = .stadium) {
            self.title = title
            self.date = date
            self.venue = venue
            self.gameUrl = gameUrl
            self.notes = notes
            self.watchLocation = watchLocation
            self.createdAt = .now
        }
    }

    @Model
    final class JerseySighting {
        var firstName: String?
        var lastName: String?
        var playerNumber: String?
        var photoData: Data?
        var photoLocalIdentifier: String?
        var timestamp: Date

        var event: Event?
        var team: Team?

        init(team: Team? = nil, firstName: String? = nil, lastName: String? = nil, playerNumber: String? = nil, photoData: Data? = nil, photoLocalIdentifier: String? = nil, event: Event? = nil) {
            self.team = team
            self.firstName = firstName
            self.lastName = lastName
            self.playerNumber = playerNumber
            self.photoData = photoData
            self.photoLocalIdentifier = photoLocalIdentifier
            self.event = event
            self.timestamp = .now
        }
    }
}

// MARK: - V2 (Current — Event with id)

enum SeenAtSchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(2, 0, 0) }
    static var models: [any PersistentModel.Type] { [Team.self, Event.self, JerseySighting.self] }
}

// MARK: - Migration Plan

enum SeenAtMigrationPlan: SchemaMigrationPlan {
    static let currentVersion = "2.0.0"
    static var schemas: [any VersionedSchema.Type] { [SeenAtSchemaV1.self, SeenAtSchemaV2.self] }
    static var stages: [MigrationStage] { [migrateV1toV2] }

    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: SeenAtSchemaV1.self,
        toVersion: SeenAtSchemaV2.self,
        willMigrate: nil,
        didMigrate: { context in
            let events = try context.fetch(FetchDescriptor<Event>())
            for event in events where event.awayTeam == nil || event.homeTeam == nil {
                if let teams = event.title.parsedTeams() {
                    event.awayTeam = teams.away
                    event.homeTeam = teams.home
                }
            }
            try context.save()
        }
    )
}
