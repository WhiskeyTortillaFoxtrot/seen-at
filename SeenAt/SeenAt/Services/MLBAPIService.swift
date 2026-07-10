import Foundation

enum MLBAPIService: LeagueAPIService {
    static func fetchGames(on date: Date, session: URLSession = .shared) async throws -> [LeagueGame] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)

        let url = URL(string: "https://statsapi.mlb.com/api/v1/schedule?date=\(dateString)&sportId=1")!
        let (data, _) = try await session.data(from: url)

        let decoder = JSONDecoder()
        let response = try decoder.decode(ScheduleResponse.self, from: data)
        return response.dates.first?.games.map { $0.toLeagueGame } ?? []
    }
}

struct ScheduleResponse: Codable {
    let dates: [ScheduleDate]
}

struct ScheduleDate: Codable {
    let games: [MLBGame]
}

struct MLBGame: Codable, Identifiable {
    let gamePk: Int
    let gameDate: String
    let teams: MLBGameTeams
    let venue: MLBGameVenue
    let dayNight: String?
    let status: MLBGameStatus

    var id: Int { gamePk }

    var title: String {
        "\(teams.away.team.name) @ \(teams.home.team.name)"
    }

    var venueName: String { venue.name }

    var isScheduled: Bool {
        status.detailedState == "Scheduled" || status.abstractGameState == "Preview"
    }

    var toLeagueGame: LeagueGame {
        LeagueGame(
            id: "mlb-\(gamePk)",
            awayTeam: teams.away.team.name,
            homeTeam: teams.home.team.name,
            venueName: venueName,
            dateString: gameDate,
            league: "mlb",
            url: URL(string: "https://www.mlb.com/gameday/\(gamePk)"),
            dayNight: dayNight
        )
    }
}

struct MLBGameTeams: Codable {
    let away: MLBTeamWrapper
    let home: MLBTeamWrapper
}

struct MLBTeamWrapper: Codable {
    let team: MLBTeam
}

struct MLBTeam: Codable {
    let id: Int
    let name: String
}

struct MLBGameVenue: Codable {
    let id: Int
    let name: String
}

struct MLBGameStatus: Codable {
    let abstractGameState: String
    let detailedState: String
    let statusCode: String
}
