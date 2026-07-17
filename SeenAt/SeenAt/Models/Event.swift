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

    @Transient private var lastCacheSightingCount: Int = -1
    @Transient private var totalCountCache: Int = 0
    @Transient private var teamBreakdownCache: [(team: Team, count: Int)] = []

    var totalCount: Int {
        refreshCachesIfNeeded()
        return totalCountCache
    }

    var teamBreakdown: [(team: Team, count: Int)] {
        refreshCachesIfNeeded()
        return teamBreakdownCache
    }

    private func refreshCachesIfNeeded() {
        guard sightings.count != lastCacheSightingCount else { return }
        lastCacheSightingCount = sightings.count
        totalCountCache = sightings.count
        let grouped = Dictionary(grouping: sightings.compactMap { $0.team == nil ? nil : $0 }) { $0.team! }
        teamBreakdownCache = grouped
            .map { ($0.key, $0.value.count) }
            .sorted { a, b in a.count > b.count || (a.count == b.count && a.team.name < b.team.name) }
    }

    var playerBreakdown: [(team: Team, playerName: String, count: Int)] {
        let withPlayer = sightings.filter { $0.isPlayerSighting }
        let grouped = Dictionary(grouping: withPlayer) { "\($0.team?.name ?? ""):\($0.displayName)" }
        return grouped
            .compactMap { (key, values) -> (team: Team, playerName: String, count: Int)? in
                guard let first = values.first, let team = first.team else { return nil }
                return (team, first.displayName, values.count)
            }
            .sorted { a, b in a.count > b.count || (a.count == b.count && a.playerName < b.playerName) }
    }

    func players(for team: Team) -> [(playerName: String, count: Int)] {
        let withPlayer = sightings.filter { $0.team?.id == team.id && $0.isPlayerSighting }
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
        if let teams = title.parsedTeams() {
            awayTeam = teams.away
            homeTeam = teams.home
        }
    }
}
