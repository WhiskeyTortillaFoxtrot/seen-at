import Foundation

/// Adapts the WNBA's public, current-season schedule feed to SeenAt's league-game model.
/// Keep the feed-specific types here: the endpoint is public but not a documented API contract.
enum WNBAAPIService: LeagueAPIService {
    static let scheduleURL = URL(string: "https://cdn.wnba.com/static/json/staticData/scheduleLeagueV2.json")!

    /// `date` is interpreted as an America/New_York instant.
    static func fetchGames(on date: Date, session: URLSession = APICacheService.session) async throws -> [LeagueGame] {
        let dateString = easternDayString(from: date)
        if let cached = APICacheService.getCachedGames(league: "wnba", date: date) {
            DiagnosticsService.shared.log(category: "WNBA", level: .debug, message: "Cache hit for WNBA \(dateString)")
            return cached
        }
        if let byDay = getIndexedScheduleIfFresh() {
            let games = byDay[dateString] ?? []
            APICacheService.setCachedGames(games, league: "wnba", date: date)
            DiagnosticsService.shared.log(category: "WNBA", level: .debug, message: "Indexed cache hit for WNBA \(dateString)")
            return games
        }

        DiagnosticsService.shared.log(category: "WNBA", level: .info, message: "Fetching WNBA schedule for \(dateString)")
        do {
            let byDay = try await fetchIndexedSchedule(session: session)
            storeIndexedSchedule(byDay)
            let games = byDay[dateString] ?? []
            APICacheService.setCachedGames(games, league: "wnba", date: date)
            DiagnosticsService.shared.log(category: "WNBA", level: .info, message: "Fetched \(games.count) WNBA games")
            return games
        } catch {
            if let byDay = getIndexedScheduleIfStale() {
                let games = byDay[dateString] ?? []
                DiagnosticsService.shared.log(category: "WNBA", level: .warning, message: "Fetch failed for WNBA, using indexed cache: \(error.localizedDescription)")
                return games
            }
            if let cached = APICacheService.getStaleGames(league: "wnba", date: date) {
                DiagnosticsService.shared.log(category: "WNBA", level: .warning, message: "Fetch failed for WNBA, using cache: \(error.localizedDescription)")
                return cached
            }
            DiagnosticsService.shared.log(category: "WNBA", level: .error, message: "Fetch failed for WNBA, no cache: \(error.localizedDescription)")
            throw error
        }
    }

    /// Fetches the games for the calendar day represented by a date picker, regardless of
    /// the device's time zone. DatePicker supplies a Date (an instant), so preserve its
    /// local year/month/day components before constructing the corresponding Eastern day.
    static func fetchGames(onCalendarDate date: Date, calendar: Calendar = .current, session: URLSession = APICacheService.session) async throws -> [LeagueGame] {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let easternDate = easternCalendar.date(from: components) else {
            throw URLError(.badURL)
        }
        return try await fetchGames(on: easternDate, session: session)
    }

    // MARK: - Indexed schedule cache (full-season, Eastern-day keyed)

    private nonisolated(unsafe) static var indexedByDay: [String: [LeagueGame]]?
    private nonisolated(unsafe) static var indexedTimestamp: Date?
    private struct InFlightSchedule {
        let id: UUID
        let task: Task<[String: [LeagueGame]], Error>
    }

    private nonisolated(unsafe) static var inFlightSchedule: InFlightSchedule?
    private static let indexedLock = NSLock()

    private static func getIndexedScheduleIfFresh() -> [String: [LeagueGame]]? {
        indexedLock.withLock {
            guard let byDay = indexedByDay, let ts = indexedTimestamp,
                  Date().timeIntervalSince(ts) < APICacheService.cacheTTL else { return nil }
            return byDay
        }
    }

    private static func getIndexedScheduleIfStale() -> [String: [LeagueGame]]? {
        indexedLock.withLock {
            guard let byDay = indexedByDay, let ts = indexedTimestamp else { return nil }
            guard Date().timeIntervalSince(ts) < APICacheService.staleWindow else {
                indexedByDay = nil
                indexedTimestamp = nil
                return nil
            }
            return byDay
        }
    }

    private static func storeIndexedSchedule(_ byDay: [String: [LeagueGame]]) {
        indexedLock.withLock {
            indexedByDay = byDay
            indexedTimestamp = Date()
        }
    }

    /// Coalesces concurrent date requests into one season-file download and decode.
    private static func fetchIndexedSchedule(session: URLSession) async throws -> [String: [LeagueGame]] {
        let inFlight = indexedLock.withLock { () -> InFlightSchedule in
            if let inFlightSchedule { return inFlightSchedule }

            let inFlight = InFlightSchedule(id: UUID(), task: Task {
                let data = try await APICacheService.validatedData(for: scheduleRequest, session: session)
                let schedule = try JSONDecoder().decode(WNBAScheduleResponse.self, from: data)
                return buildIndexedMap(from: schedule)
            })
            inFlightSchedule = inFlight
            return inFlight
        }

        defer {
            indexedLock.withLock {
                guard inFlightSchedule?.id == inFlight.id else { return }
                inFlightSchedule = nil
            }
        }
        return try await inFlight.task.value
    }

    static func clearIndexedCacheForTesting() {
        indexedLock.withLock {
            indexedByDay = nil
            indexedTimestamp = nil
            inFlightSchedule = nil
        }
    }

    private static func buildIndexedMap(from schedule: WNBAScheduleResponse) -> [String: [LeagueGame]] {
        var map: [String: [LeagueGame]] = [:]
        for game in schedule.leagueSchedule.gameDates.flatMap(\.games) {
            guard let startUTC = game.gameDateTimeUTC,
                  let start = isoUTCDate(from: startUTC) ?? parseISODate(startUTC) else { continue }
            let day = easternDayString(from: start)
            map[day, default: []].append(game.leagueGame(dateString: startUTC))
        }
        return map
    }

    /// The feed groups games by Eastern Time day (its `gameDate` labels are MM/dd/yyyy
    /// Eastern days), so games are matched by their Eastern calendar day rather than the
    /// device's time zone. The shared formatter is mutated only read-only and guarded by a
    /// lock to match the caching layer's convention (APICacheService).
    private static let easternDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let easternCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    private static let easternDayLock = NSLock()

    private static func easternDayString(from date: Date) -> String {
        easternDayLock.withLock { easternDayFormatter.string(from: date) }
    }

    /// Cached parser for the feed's `yyyy-MM-dd'T'HH:mm:ssZ` timestamps; falls back to the
    /// broader `parseISODate` for any non-standard shapes. The shared formatter is immutable
    /// and only read under the lock, mirroring the eastern-day formatter's convention.
    private nonisolated(unsafe) static let isoUTCFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let isoLock = NSLock()

    private static func isoUTCDate(from string: String) -> Date? {
        isoLock.withLock { isoUTCFormatter.date(from: string) }
    }

    private static var scheduleRequest: URLRequest {
        APICacheService.makeRequest(url: scheduleURL)
    }
}

private struct WNBAScheduleResponse: Decodable {
    let leagueSchedule: WNBALeagueSchedule
}

private struct WNBALeagueSchedule: Decodable {
    let gameDates: [WNBAGameDate]
}

private struct WNBAGameDate: Decodable {
    let games: [WNBAScheduleGame]
}

/// The NBA-platform feeds have encoded `gameId` as both a JSON string and a
/// JSON number across seasons; accept either representation.
private struct WNBAGameID: Decodable {
    let rawValue: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            rawValue = value
        } else {
            rawValue = String(try container.decode(Int.self))
        }
    }
}

private struct WNBAScheduleGame: Decodable {
    let gameId: WNBAGameID
    let gameDateTimeUTC: String?
    let awayTeam: WNBAScheduleTeam
    let homeTeam: WNBAScheduleTeam
    let arenaName: String?

    func leagueGame(dateString: String) -> LeagueGame {
        LeagueGame(
            id: "wnba-\(gameId.rawValue)",
            awayTeam: awayTeam.displayName,
            homeTeam: homeTeam.displayName,
            venueName: arenaName ?? "",
            dateString: dateString,
            league: "wnba",
            url: nil,
            dayNight: nil
        )
    }
}

private struct WNBAScheduleTeam: Decodable {
    let teamCity: String
    let teamName: String

    var displayName: String { "\(teamCity) \(teamName)" }
}
