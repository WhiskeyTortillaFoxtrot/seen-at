import SwiftData

@MainActor
protocol SettingsServiceDependencies {
    func fetchSightings(from context: ModelContext) throws -> [JerseySighting]
    func fetchEvents(from context: ModelContext) throws -> [Event]
    func save(context: ModelContext, message: String) -> Bool
    func rollback(context: ModelContext)
    func endAllActivities() async
    func clearPhotoCache()
}

@MainActor
struct DefaultSettingsServiceDependencies: SettingsServiceDependencies {
    func fetchSightings(from context: ModelContext) throws -> [JerseySighting] {
        try context.fetch(FetchDescriptor<JerseySighting>())
    }

    func fetchEvents(from context: ModelContext) throws -> [Event] {
        try context.fetch(FetchDescriptor<Event>())
    }

    func save(context: ModelContext, message: String) -> Bool {
        context.saveAndLog(message)
    }

    func rollback(context: ModelContext) {
        context.rollback()
    }

    func endAllActivities() async {
        await LiveActivityManager.endAll()
    }

    func clearPhotoCache() {
        PhotoCacheService.clear()
    }
}

@MainActor
enum SettingsService {
    static func deleteAllSightings(
        context: ModelContext,
        dependencies: any SettingsServiceDependencies = DefaultSettingsServiceDependencies()
    ) -> Bool {
        guard let sightings = try? dependencies.fetchSightings(from: context) else {
            return false
        }
        for sighting in sightings {
            context.delete(sighting)
        }
        let saved = dependencies.save(context: context, message: "Failed to delete all sightings")
        if !saved {
            dependencies.rollback(context: context)
        }
        return saved
    }

    static func resetAllData(
        context: ModelContext,
        dependencies: any SettingsServiceDependencies = DefaultSettingsServiceDependencies()
    ) async -> Bool {
        let events: [Event]
        let sightings: [JerseySighting]
        do {
            events = try dependencies.fetchEvents(from: context)
            sightings = try dependencies.fetchSightings(from: context)
        } catch {
            return false
        }

        for event in events {
            context.delete(event)
        }
        for sighting in sightings {
            context.delete(sighting)
        }

        let saved = dependencies.save(context: context, message: "Failed to reset all data")
        if !saved {
            dependencies.rollback(context: context)
            return false
        }

        await dependencies.endAllActivities()
        dependencies.clearPhotoCache()
        return true
    }
}
