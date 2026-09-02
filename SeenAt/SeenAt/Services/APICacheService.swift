import Foundation

enum APICacheService {
    static let cacheTTL: TimeInterval = 300
    static let staleWindow: TimeInterval = 6 * 60 * 60
    static let maxEntries = 64
    static let maxValidatedBytes = 2 * 1024 * 1024

    static let session: URLSession = {
        let cache = URLCache(memoryCapacity: 5_000_000, diskCapacity: 20_000_000, diskPath: "api-cache")
        let config = URLSessionConfiguration.default
        config.urlCache = cache
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        config.httpShouldSetCookies = false
        config.httpCookieStorage = nil
        config.httpCookieAcceptPolicy = .never
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
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

    /// Fresh entry within `cacheTTL`. Expired entries are kept for bounded stale-on-error use.
    static func getCachedGames(league: String, date: Date) -> [LeagueGame]? {
        let key = cacheKey(league: league, date: date)
        return cacheLock.withLock {
            guard let entry = cache[key] else { return nil }
            guard Date().timeIntervalSince(entry.timestamp) < cacheTTL else { return nil }
            return entry.games
        }
    }

    /// Entry within the 6h stale window, for offline fallback after a network failure.
    /// Entries beyond the window are evicted lazily.
    static func getStaleGames(league: String, date: Date) -> [LeagueGame]? {
        let key = cacheKey(league: league, date: date)
        return cacheLock.withLock {
            guard let entry = cache[key] else { return nil }
            let age = Date().timeIntervalSince(entry.timestamp)
            guard age < staleWindow else {
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
            pruneIfNeededLocked()
        }
    }

    /// Test helper: inject an entry with a controlled timestamp to simulate TTL/stale expiry.
    static func setCachedGames(_ games: [LeagueGame], league: String, date: Date, timestamp: Date) {
        let key = cacheKey(league: league, date: date)
        cacheLock.withLock {
            cache[key] = CacheEntry(games: games, timestamp: timestamp)
            pruneIfNeededLocked()
        }
    }

    static func clearCache() {
        cacheLock.withLock {
            cache.removeAll()
        }
    }

    // MARK: - Shared HTTP boundary

    static func makeRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("SeenAt/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30
        return request
    }

    /// Validates that the response is `200...299`, that an explicit Content-Type (when present)
    /// is JSON, and that the payload does not exceed `maxValidatedBytes`. A missing
    /// Content-Type is tolerated because `HTTPURLResponse` synthesizes `text/plain` on
    /// device even when the server sent no header.
    static func validatedData(for request: URLRequest, session: URLSession) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode
        else {
            throw URLError(.badServerResponse)
        }
        if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
           !contentType.lowercased().contains("json") {
            throw URLError(.badServerResponse)
        }
        guard data.count < maxValidatedBytes else {
            throw URLError(.dataLengthExceedsMaximum)
        }
        return data
    }

    // MARK: - Private

    /// Must be called with `cacheLock` held.
    private static func pruneIfNeededLocked() {
        guard cache.count > maxEntries else { return }
        let sorted = cache.sorted { $0.value.timestamp < $1.value.timestamp }
        let toRemove = cache.count - maxEntries
        for (key, _) in sorted.prefix(toRemove) {
            cache.removeValue(forKey: key)
        }
    }
}
