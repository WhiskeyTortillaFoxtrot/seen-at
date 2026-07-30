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
            DiagnosticsService.shared.log(category: "DeepLink", level: .warning, message: "Deep link event not found: \(eventID.uuidString.prefix(8))...")
            return .notFound
        }
        DiagnosticsService.shared.log(category: "DeepLink", level: .info, message: "Deep link resolved to event: \(event.title)")
        return .openEvent(event, selectedTab: 0)
    }
}
