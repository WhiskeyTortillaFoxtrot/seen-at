import Foundation

struct LeagueGame: Identifiable {
    let id: String
    let awayTeam: String
    let homeTeam: String
    let venueName: String
    let dateString: String
    let league: String
    let url: URL?
    let dayNight: String?

    var title: String { "\(awayTeam) @ \(homeTeam)" }
}
