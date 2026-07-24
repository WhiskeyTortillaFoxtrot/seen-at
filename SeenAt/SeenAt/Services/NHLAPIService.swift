import Foundation

enum NHLAPIService: LeagueAPIService {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func fetchGames(on date: Date, session: URLSession = APICacheService.session) async throws -> [LeagueGame] {
        let dateString = dateFormatter.string(from: date)

        if let cached = APICacheService.getCachedGames(league: "nhl", date: date) {
            return cached
        }

        let url = URL(string: "https://api-web.nhle.com/v1/schedule/\(dateString)")!
        do {
            let (data, _) = try await session.data(from: url)
            let decoder = JSONDecoder()
            let response = try decoder.decode(NHLScheduleResponse.self, from: data)
            let games = response.gameWeek.first(where: { $0.date == dateString })?.games.map { $0.toLeagueGame(dateString: dateString) } ?? []
            APICacheService.setCachedGames(games, league: "nhl", date: date)
            return games
        } catch {
            if let cached = APICacheService.getCachedGames(league: "nhl", date: date) {
                return cached
            }
            throw error
        }
    }
}

struct NHLScheduleResponse: Codable {
    let gameWeek: [NHLGameWeek]
}

struct NHLGameWeek: Codable {
    let date: String
    let games: [NHLGame]
}

struct NHLGame: Codable {
    let id: Int
    let venue: NHLVenue
    let homeTeam: NHLTeamWrapper
    let awayTeam: NHLTeamWrapper
    let gameLink: String?

    var title: String {
        "\(awayTeam.name.default) @ \(homeTeam.name.default)"
    }

    func toLeagueGame(dateString: String) -> LeagueGame {
        LeagueGame(
            id: "nhl-\(id)",
            awayTeam: awayTeam.name.default,
            homeTeam: homeTeam.name.default,
            venueName: venue.default,
            dateString: dateString,
            league: "nhl",
            url: gameLink.flatMap(URL.init),
            dayNight: nil
        )
    }
}

struct NHLVenue: Codable {
    let `default`: String
}

struct NHLTeamWrapper: Codable {
    let name: NHLTeamName
}

struct NHLTeamName: Codable {
    let `default`: String
}
