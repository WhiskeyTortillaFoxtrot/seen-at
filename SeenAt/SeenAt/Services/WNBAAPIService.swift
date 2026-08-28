import Foundation

/// Adapts the WNBA's public, current-season schedule feed to SeenAt's league-game model.
/// Keep the feed-specific types here: the endpoint is public but not a documented API contract.
enum WNBAAPIService: LeagueAPIService {
    static let scheduleURL = URL(string: "https://cdn.wnba.com/static/json/staticData/scheduleLeagueV2.json")!

    private static var scheduleRequest: URLRequest {
        var request = URLRequest(url: scheduleURL)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("https://www.wnba.com", forHTTPHeaderField: "Origin")
        request.setValue("https://www.wnba.com/", forHTTPHeaderField: "Referer")
        request.setValue("SeenAt/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        return request
    }

    /// The feed schedules by Eastern Time day (its `gameDate` group labels are
    /// MM/dd/yyyy Eastern days), so both the requested date and each game's day
    /// are compared in America/New_York rather than the device's time zone.
    private static let easternDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func fetchGames(on date: Date, session: URLSession = APICacheService.session) async throws -> [LeagueGame] {
        let dateString = easternDayFormatter.string(from: date)
        if let cached = APICacheService.getCachedGames(league: "wnba", date: date) {
            DiagnosticsService.shared.log(category: "WNBA", level: .debug, message: "Cache hit for WNBA \(dateString)")
            return cached
        }

        DiagnosticsService.shared.log(category: "WNBA", level: .info, message: "Fetching WNBA schedule for \(dateString)")
        do {
            let (data, response) = try await session.data(for: scheduleRequest)
            guard let httpResponse = response as? HTTPURLResponse,
                  200...299 ~= httpResponse.statusCode
            else {
                throw URLError(.badServerResponse)
            }

            let schedule = try JSONDecoder().decode(WNBAScheduleResponse.self, from: data)
            let games = schedule.leagueSchedule.gameDates
                .flatMap(\.games)
                .compactMap { game -> LeagueGame? in
                    guard let startUTC = game.gameDateTimeUTC,
                          let start = parseISODate(startUTC),
                          easternDayFormatter.string(from: start) == dateString
                    else { return nil }
                    return game.leagueGame(dateString: startUTC)
                }
            APICacheService.setCachedGames(games, league: "wnba", date: date)
            DiagnosticsService.shared.log(category: "WNBA", level: .info, message: "Fetched \(games.count) WNBA games")
            return games
        } catch {
            if let cached = APICacheService.getCachedGames(league: "wnba", date: date) {
                DiagnosticsService.shared.log(category: "WNBA", level: .warning, message: "Fetch failed for WNBA, using cache: \(error.localizedDescription)")
                return cached
            }
            DiagnosticsService.shared.log(category: "WNBA", level: .error, message: "Fetch failed for WNBA, no cache: \(error.localizedDescription)")
            throw error
        }
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
