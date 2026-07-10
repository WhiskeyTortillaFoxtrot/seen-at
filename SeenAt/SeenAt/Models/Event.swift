import Foundation
import SwiftData

enum WatchLocation: String, Codable {
    case stadium
    case tv
}

@Model
final class Event {
    @Attribute(.unique) var id: UUID = UUID()
    var awayTeam: String?
    var homeTeam: String?
    var title: String
    var date: Date
    var venue: String?
    var gameUrl: String?
    var notes: String?
    var createdAt: Date
    var watchLocation: WatchLocation?

    @Relationship(deleteRule: .cascade)
    var sightings: [JerseySighting] = []

    var totalCount: Int { sightings.count }

    var teamBreakdown: [(team: Team, count: Int)] {
        let grouped = Dictionary(grouping: sightings.compactMap { $0.team == nil ? nil : $0 }) { $0.team! }
        return grouped
            .map { ($0.key, $0.value.count) }
            .sorted { a, b in a.count > b.count || (a.count == b.count && a.team.name < b.team.name) }
    }

    var playerBreakdown: [(team: Team, playerName: String, count: Int)] {
        let withPlayer = sightings.filter { !$0.displayName.isEmpty }
        let grouped = Dictionary(grouping: withPlayer) { "\($0.team?.name ?? ""):\($0.displayName)" }
        return grouped
            .compactMap { (key, values) -> (team: Team, playerName: String, count: Int)? in
                guard let first = values.first, let team = first.team else { return nil }
                return (team, first.displayName, values.count)
            }
            .sorted { a, b in a.count > b.count || (a.count == b.count && a.playerName < b.playerName) }
    }

    func players(for team: Team) -> [(playerName: String, count: Int)] {
        let withPlayer = sightings.filter { $0.team?.id == team.id && !$0.displayName.isEmpty }
        let grouped = Dictionary(grouping: withPlayer) { $0.displayName }
        return grouped.map { ($0.key, $0.value.count) }.sorted { a, b in a.count > b.count || (a.count == b.count && a.playerName < b.playerName) }
    }

    init(awayTeam: String, homeTeam: String, date: Date, venue: String? = nil, gameUrl: String? = nil, notes: String? = nil, watchLocation: WatchLocation? = .stadium) {
        self.awayTeam = awayTeam
        self.homeTeam = homeTeam
        self.title = "\(awayTeam) @ \(homeTeam)"
        self.date = date
        self.venue = venue
        self.gameUrl = gameUrl
        self.notes = notes
        self.watchLocation = watchLocation
        self.createdAt = .now
    }

    init(title: String, date: Date, venue: String? = nil, gameUrl: String? = nil, notes: String? = nil, watchLocation: WatchLocation? = .stadium) {
        self.title = title
        self.date = date
        self.venue = venue
        self.gameUrl = gameUrl
        self.notes = notes
        self.watchLocation = watchLocation
        self.createdAt = .now
        let parts = title.components(separatedBy: " @ ")
        if parts.count == 2 {
            awayTeam = parts[0].trimmingCharacters(in: .whitespaces)
            homeTeam = parts[1].trimmingCharacters(in: .whitespaces)
        }
    }
}
