import Foundation

protocol LeagueAPIService {
    static func fetchGames(on date: Date, session: URLSession) async throws -> [LeagueGame]
}
