import Foundation

/// Adapts the WNBA's public, current-season schedule feed to SeenAt's league-game model.
/// Keep the feed-specific types here: the endpoint is public but not a documented API contract.
enum WNBAAPIService: LeagueAPIService {
    static let scheduleURL = URL(string: "https://cdn.wnba.com/static/json/staticData/scheduleLeagueV2.json")!

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "America/New_York")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func fetchGames(on date: Date, session: URLSession = APICacheService.session) async throws -> [LeagueGame] {
        let dateString = dateFormatter.string(from: date)
        if let cached = APICacheService.getCachedGames(league: "wnba", date: date) {
            DiagnosticsService.shared.log(category: "WNBA", level: .debug, message: "Cache hit for WNBA \(dateString)")
            return cached
        }

        DiagnosticsService.shared.log(category: "WNBA", level: .info, message: "Fetching WNBA schedule for \(dateString)")
        do {
            let (data, response) = try await session.data(from: scheduleURL)
            guard let httpResponse = response as? HTTPURLResponse,
                  200...299 ~= httpResponse.statusCode
            else {
                throw URLError(.badServerResponse)
            }

            let schedule = try JSONDecoder().decode(WNBAScheduleResponse.self, from: data)
            let games = schedule.leagueSchedule.gameDates
                .first(where: { $0.gameDate == dateString })?
                .games
                .map(\.leagueGame) ?? []
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
    let gameDate: String
    let games: [WNBAScheduleGame]
}

private struct WNBAScheduleGame: Decodable {
    let gameId: String
    let gameDateTimeUTC: String
    let awayTeam: WNBAScheduleTeam
    let homeTeam: WNBAScheduleTeam
    let arenaName: String?

    var leagueGame: LeagueGame {
        LeagueGame(
            id: "wnba-\(gameId)",
            awayTeam: awayTeam.displayName,
            homeTeam: homeTeam.displayName,
            venueName: arenaName ?? "",
            dateString: gameDateTimeUTC,
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
