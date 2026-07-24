import Foundation

enum DeepLinkParseError: Error, Equatable {
    case invalidScheme
    case invalidHost
    case invalidUUID
}

enum DeepLinkParser {
    static func parse(_ url: URL) -> Result<UUID, DeepLinkParseError> {
        if url.scheme?.lowercased() != "seenat" {
            return Result.failure(.invalidScheme)
        }
        if url.host?.lowercased() != "live-tracking" {
            return Result.failure(.invalidHost)
        }
        guard let eventID = UUID(uuidString: url.lastPathComponent) else {
            return Result.failure(.invalidUUID)
        }
        return Result.success(eventID)
    }
}
