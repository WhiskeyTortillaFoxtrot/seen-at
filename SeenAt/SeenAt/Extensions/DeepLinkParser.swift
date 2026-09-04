import Foundation

enum DeepLinkParseError: Error, Equatable {
    case invalidScheme
    case invalidHost
    case invalidUUID
}

enum DeepLinkDestination: Equatable {
    case liveTracking(UUID)
    case eventSummary(UUID)
    case stats
}

enum DeepLinkParser {
    static func parse(_ url: URL) -> Result<DeepLinkDestination, DeepLinkParseError> {
        if url.scheme?.lowercased() != "seenat" {
            return Result.failure(.invalidScheme)
        }

        switch url.host?.lowercased() {
        case "stats":
            return Result.success(.stats)
        case "live-tracking", "event-summary":
            guard let eventID = UUID(uuidString: url.lastPathComponent) else {
                return Result.failure(.invalidUUID)
            }
            if url.host?.lowercased() == "event-summary" {
                return Result.success(.eventSummary(eventID))
            }
            return Result.success(.liveTracking(eventID))
        default:
            return Result.failure(.invalidHost)
        }
    }
}
