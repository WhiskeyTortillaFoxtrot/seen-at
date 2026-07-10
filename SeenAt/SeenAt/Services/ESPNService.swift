import Foundation

enum ESPNService {
    static func fetchGames(on date: Date, sportPath: String, session: URLSession = .shared) async throws -> [LeagueGame] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let dateString = formatter.string(from: date)

        let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/\(sportPath)/scoreboard?dates=\(dateString)")!
        let (data, _) = try await session.data(from: url)

        let decoder = JSONDecoder()
        let response = try decoder.decode(ESPNResponse.self, from: data)
        return response.events.map { $0.toLeagueGame(sportPath: sportPath) }
    }
}

struct ESPNResponse: Codable {
    let events: [ESPNEvent]
}

struct ESPNEvent: Codable, Identifiable {
    let id: String
    let name: String
    let date: String
    let competitions: [ESPNCompetition]

    func toLeagueGame(sportPath: String) -> LeagueGame {
        let league: String
        if sportPath.contains("nba") {
            league = "nba"
        } else if sportPath.contains("nfl") {
            league = "nfl"
        } else {
            league = sportPath
        }

        let venueName = competitions.first?.venue?.fullName ?? ""
        let awayName = competitions.first?.competitors.first(where: { $0.homeAway == "away" })?.team.name ?? ""
        let homeName = competitions.first?.competitors.first(where: { $0.homeAway == "home" })?.team.name ?? ""
        let title = "\(awayName) @ \(homeName)"

        return LeagueGame(
            id: "\(league)-\(id)",
            title: title,
            venueName: venueName,
            dateString: date,
            league: league,
            url: nil,
            dayNight: nil
        )
    }
}

struct ESPNCompetition: Codable {
    let venue: ESPNVenue?
    let competitors: [ESPNCompetitor]
}

struct ESPNVenue: Codable {
    let fullName: String
}

struct ESPNCompetitor: Codable {
    let homeAway: String
    let team: ESPNSimpleTeam
}

struct ESPNSimpleTeam: Codable {
    let name: String
}
