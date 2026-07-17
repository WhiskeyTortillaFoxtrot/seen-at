import Foundation
import SwiftData

@Model
final class JerseySighting {
    var firstName: String?
    var lastName: String?
    var playerNumber: String?
    @Attribute(.externalStorage) var photoData: Data?
    var photoLocalIdentifier: String?
    var timestamp: Date

    @Relationship(inverse: \Event.sightings) var event: Event?

    @Relationship(inverse: \Team.sightings) var team: Team?

    var isPlayerSighting: Bool {
        firstName != nil || lastName != nil || playerNumber != nil
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
