import Foundation
import SwiftData

@MainActor
enum DeepLinkService {
    enum Resolution {
        case openEvent(Event, selectedTab: Int)
        case notFound
    }

    static func fetchEvent(by id: UUID, context: ModelContext) throws -> Event? {
        let predicate = #Predicate<Event> { $0.id == id }
        let descriptor = FetchDescriptor(predicate: predicate)
        return try context.fetch(descriptor).first
    }

    static func resolve(eventID: UUID, context: ModelContext) throws -> Resolution {
        guard let event = try fetchEvent(by: eventID, context: context) else {
            return .notFound
        }
        return .openEvent(event, selectedTab: 0)
    }
}
