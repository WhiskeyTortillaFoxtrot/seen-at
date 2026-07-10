import Foundation

enum NHLAPIService: LeagueAPIService {
    static func fetchGames(on date: Date, session: URLSession = .shared) async throws -> [LeagueGame] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)

        let url = URL(string: "https://api-web.nhle.com/v1/schedule/\(dateString)")!
        let (data, _) = try await session.data(from: url)

        let decoder = JSONDecoder()
        let response = try decoder.decode(NHLScheduleResponse.self, from: data)
        return response.gameWeek.flatMap { week in
            week.games.map { $0.toLeagueGame(dateString: week.date) }
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

    var title: String {
        "\(awayTeam.name.default) @ \(homeTeam.name.default)"
    }

    func toLeagueGame(dateString: String) -> LeagueGame {
        LeagueGame(
            id: "nhl-\(id)",
            title: title,
            venueName: venue.default,
            dateString: dateString,
            league: "nhl",
            url: nil,
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
