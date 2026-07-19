import Foundation
import SwiftData

struct EventActionHandler {
    static func incrementPlayer(team: Team, name: String, event: Event, context: ModelContext, lastIncrementTimes: inout [String: Date]) {
        guard !EventPreviewPolicy.isReadOnly(event) else { return }
        let key = "\(team.id):\(name)"
        let now = Date()
        guard now.timeIntervalSince(lastIncrementTimes[key, default: .distantPast]) > 0.3 else { return }

        let reference = event.sightings.first { $0.team?.id == team.id && $0.displayName == name }
        let sighting = JerseySighting(
            team: team,
            firstName: reference?.firstName,
            lastName: reference?.lastName,
            playerNumber: reference?.playerNumber,
            event: event
        )
        context.insert(sighting)
        guard context.saveAndLog("Failed to save incrementPlayer sighting") else {
            context.delete(sighting)
            return
        }
        lastIncrementTimes[key] = now
    }

    static func deletePlayer(team: Team, name: String, event: Event, context: ModelContext) -> Bool {
        guard !EventPreviewPolicy.isReadOnly(event) else { return false }
        let toDelete = event.sightings.filter { $0.team?.id == team.id && $0.displayName == name }
        for sighting in toDelete {
            context.delete(sighting)
        }
        guard context.saveAndLog("Failed to save deletePlayer deletion") else {
            context.rollback()
            return false
        }
        return true
    }

    static func disabledForDebounce(team: Team, name: String, lastIncrementTimes: [String: Date]) -> Bool {
        let key = "\(team.id):\(name)"
        return Date().timeIntervalSince(lastIncrementTimes[key, default: .distantPast]) < 0.3
    }
}
