import Foundation
import SwiftData

@Model
final class JerseySighting {
    var firstName: String?
    var lastName: String?
    var playerNumber: String?
    /// Added in V3 (2026-07-15): photo blobs were migrated to on-disk storage
    /// to reduce model-store size.  The migration plan must copy files from the
    /// old in-row `photoData` column into the on-disk `.externalStorage` directory
    /// before the column is dropped.
    @Attribute(.externalStorage) var photoData: Data?
    var photoLocalIdentifier: String?
    var timestamp: Date

    @Relationship(inverse: \Event.sightings) var event: Event?

    @Relationship(inverse: \Team.sightings) var team: Team?

    var isPlayerSighting: Bool {
        (firstName?.isEmpty == false) || (lastName?.isEmpty == false) || (playerNumber?.isEmpty == false)
    }

    var displayName: String {
        let name = [firstName, lastName].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
        if !name.isEmpty { return name }
        if let number = playerNumber, !number.isEmpty { return "#\(number)" }
        return team?.name ?? ""
    }

    init(
        team: Team? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        playerNumber: String? = nil,
        photoData: Data? = nil,
        photoLocalIdentifier: String? = nil,
        event: Event? = nil
    ) {
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
