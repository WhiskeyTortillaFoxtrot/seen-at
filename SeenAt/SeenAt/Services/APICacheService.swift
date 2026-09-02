import Foundation

enum APICacheService {
    static let cacheTTL: TimeInterval = 300
    static let staleWindow: TimeInterval = 6 * 60 * 60
    static let maxEntries = 64
    static let maxValidatedBytes = 2 * 1024 * 1024

    static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        config.httpShouldSetCookies = false
        config.httpCookieStorage = nil
        config.httpCookieAcceptPolicy = .never
        config.urlCredentialStorage = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        return URLSession(configuration: config)
    }()

    struct CacheEntry {
        let games: [LeagueGame]
        let timestamp: Date
        var lastAccessed: Date
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
    /// On a hit the entry's `lastAccessed` is refreshed so frequently-read schedules survive
    /// oldest-entry pruning (LRU).
    static func getCachedGames(league: String, date: Date) -> [LeagueGame]? {
        let key = cacheKey(league: league, date: date)
        return cacheLock.withLock {
            guard var entry = cache[key] else { return nil }
            guard Date().timeIntervalSince(entry.timestamp) < cacheTTL else { return nil }
            entry.lastAccessed = Date()
            cache[key] = entry
            return entry.games
        }
    }

    /// Entry within the 6h stale window, for offline fallback after a network failure.
    /// Entries beyond the window are evicted lazily. On a hit `lastAccessed` is refreshed.
    static func getStaleGames(league: String, date: Date) -> [LeagueGame]? {
        let key = cacheKey(league: league, date: date)
        return cacheLock.withLock {
            guard var entry = cache[key] else { return nil }
            let age = Date().timeIntervalSince(entry.timestamp)
            guard age < staleWindow else {
                cache.removeValue(forKey: key)
                return nil
            }
            entry.lastAccessed = Date()
            cache[key] = entry
            return entry.games
        }
    }

    static func setCachedGames(_ games: [LeagueGame], league: String, date: Date) {
        let key = cacheKey(league: league, date: date)
        cacheLock.withLock {
            let now = Date()
            cache[key] = CacheEntry(games: games, timestamp: now, lastAccessed: now)
            pruneOldestIfNeededLocked()
        }
    }

    /// Test helper: inject an entry with a controlled timestamp to simulate TTL/stale expiry.
    static func setCachedGames(_ games: [LeagueGame], league: String, date: Date, timestamp: Date) {
        let key = cacheKey(league: league, date: date)
        cacheLock.withLock {
            cache[key] = CacheEntry(games: games, timestamp: timestamp, lastAccessed: timestamp)
            pruneOldestIfNeededLocked()
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
    /// device even when the server sent no header. The `Content-Length` is preflighted when
    /// available, and the body is streamed so a malicious endpoint cannot force more than
    /// 2 MB to be buffered before the error is surfaced.
    static func validatedData(for request: URLRequest, session: URLSession) async throws -> Data {
        // Use the async bytes API so we can abort once the limit is exceeded instead of
        // buffering an unbounded response via `data(for:)`.
        let (bytes, response) = try await session.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode
        else {
            throw URLError(.badServerResponse)
        }
        if let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type"),
           !contentType.lowercased().contains("json") {
            throw URLError(.badServerResponse)
        }
        if httpResponse.expectedContentLength > 0,
           httpResponse.expectedContentLength >= Int64(maxValidatedBytes) {
            throw URLError(.dataLengthExceedsMaximum)
        }
        var data = Data()
        if httpResponse.expectedContentLength > 0 {
            data.reserveCapacity(min(Int(httpResponse.expectedContentLength), maxValidatedBytes))
        }
        for try await byte in bytes {
            data.append(byte)
            if data.count >= maxValidatedBytes {
                throw URLError(.dataLengthExceedsMaximum)
            }
        }
        return data
    }

    // MARK: - Private

    /// Evicts the least-recently-used entries when over `maxEntries`. Must be called with
    /// `cacheLock` held. Eviction is LRU by `lastAccessed`, so a read keeps an entry alive.
    private static func pruneOldestIfNeededLocked() {
        guard cache.count > maxEntries else { return }
        let sorted = cache.sorted { $0.value.lastAccessed < $1.value.lastAccessed }
        let toRemove = cache.count - maxEntries
        for (key, _) in sorted.prefix(toRemove) {
            cache.removeValue(forKey: key)
        }
    }
}
