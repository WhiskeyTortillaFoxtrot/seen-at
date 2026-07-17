import Foundation

enum NHLAPIService: LeagueAPIService {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func fetchGames(on date: Date, session: URLSession = APICacheService.session) async throws -> [LeagueGame] {
        let dateString = dateFormatter.string(from: date)

        let url = URL(string: "https://api-web.nhle.com/v1/schedule/\(dateString)")!
        let (data, _) = try await session.data(from: url)

        let decoder = JSONDecoder()
        let response = try decoder.decode(NHLScheduleResponse.self, from: data)
        return response.gameWeek.first(where: { $0.date == dateString })?.games.map { $0.toLeagueGame(dateString: dateString) } ?? []
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
            awayTeam: awayTeam.name.default,
            homeTeam: homeTeam.name.default,
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
