import Foundation

enum APICacheService {
    static let cacheTTL: TimeInterval = 300

    static let session: URLSession = {
        let cache = URLCache(memoryCapacity: 5_000_000, diskCapacity: 20_000_000, diskPath: "api-cache")
        let config = URLSessionConfiguration.default
        config.urlCache = cache
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    struct CacheEntry {
        let games: [LeagueGame]
        let timestamp: Date
    }

    // The cache is accessed by concurrent API tasks; both the dictionary and
    // its date formatter must be protected independently.
    nonisolated(unsafe) private static var cache: [String: CacheEntry] = [:]
    private static let cacheLock = NSLock()
    private static let cacheDateLock = NSLock()

    private static let cacheDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func cacheKey(league: String, date: Date) -> String {
        let dateString = cacheDateLock.withLock {
            cacheDateFormatter.string(from: date)
        }
        return "\(league)-\(dateString)"
    }

    static func getCachedGames(league: String, date: Date) -> [LeagueGame]? {
        let key = cacheKey(league: league, date: date)
        return cacheLock.withLock {
            guard let entry = cache[key] else { return nil }
            guard Date().timeIntervalSince(entry.timestamp) < cacheTTL else {
                cache.removeValue(forKey: key)
                return nil
            }
            return entry.games
        }
    }

    static func setCachedGames(_ games: [LeagueGame], league: String, date: Date) {
        let key = cacheKey(league: league, date: date)
        cacheLock.withLock {
            cache[key] = CacheEntry(games: games, timestamp: Date())
        }
    }

    static func clearCache() {
        cacheLock.withLock {
            cache.removeAll()
        }
    }
}
