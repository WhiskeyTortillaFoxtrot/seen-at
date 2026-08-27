import Foundation
import SwiftData

enum SightingEditingService {
    static func update(
        _ sighting: JerseySighting,
        team: Team,
        firstName: String?,
        lastName: String?,
        playerNumber: String?,
        photoData: Data?,
        context: ModelContext
    ) -> Bool {
        guard let event = sighting.event, !EventPreviewPolicy.isReadOnly(event) else { return false }

        let previousTeam = sighting.team
        let previousFirstName = sighting.firstName
        let previousLastName = sighting.lastName
        let previousPlayerNumber = sighting.playerNumber
        let previousPhotoData = sighting.photoData
        let previousPhotoLocalIdentifier = sighting.photoLocalIdentifier

        sighting.team = team
        sighting.firstName = firstName
        sighting.lastName = lastName
        sighting.playerNumber = playerNumber
        sighting.photoData = photoData
        sighting.photoLocalIdentifier = nil
        PhotoCacheService.evict(sightingID: "\(sighting.persistentModelID)")

        guard context.saveAndLog("Failed to save sighting edit") else {
            sighting.team = previousTeam
            sighting.firstName = previousFirstName
            sighting.lastName = previousLastName
            sighting.playerNumber = previousPlayerNumber
            sighting.photoData = previousPhotoData
            sighting.photoLocalIdentifier = previousPhotoLocalIdentifier
            PhotoCacheService.evict(sightingID: "\(sighting.persistentModelID)")
            return false
        }

        return true
    }

    static func delete(_ sighting: JerseySighting, context: ModelContext) -> Bool {
        guard let event = sighting.event, !EventPreviewPolicy.isReadOnly(event) else { return false }

        let sightingID = "\(sighting.persistentModelID)"
        context.delete(sighting)
        guard context.saveAndLog("Failed to delete sighting") else {
            context.rollback()
            return false
        }

        PhotoCacheService.evict(sightingID: sightingID)
        return true
    }
}
