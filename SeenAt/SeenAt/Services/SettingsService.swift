import SwiftData

@MainActor
enum SettingsService {
    static func deleteAllSightings(context: ModelContext) -> Bool {
        guard let sightings = try? context.fetch(FetchDescriptor<JerseySighting>()) else {
            return false
        }
        for sighting in sightings {
            context.delete(sighting)
        }
        return context.saveAndLog("Failed to delete all sightings")
    }

    static func resetAllData(context: ModelContext) async -> Bool {
        await LiveActivityManager.endAll()
        PhotoCacheService.clear()

        guard let events = try? context.fetch(FetchDescriptor<Event>()) else {
            return false
        }
        for event in events {
            context.delete(event)
        }
        return context.saveAndLog("Failed to reset all data")
    }
}
