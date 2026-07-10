import Foundation

struct LeagueGame: Identifiable {
    let id: String
    let title: String
    let venueName: String
    let dateString: String
    let league: String
    let url: URL?
    let dayNight: String?
}
