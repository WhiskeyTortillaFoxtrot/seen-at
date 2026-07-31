import Foundation
import Observation

struct StatsCacheKey: Equatable {
    let selectedYear: Int?
    let events: [EventSnapshot]

    init(events: [Event], selectedYear: Int?) {
        self.selectedYear = selectedYear
        self.events = events.map(EventSnapshot.init)
    }
}

struct EventSnapshot: Equatable {
    let id: UUID
    let date: Date
    let venue: String?
    let watchLocation: String?
    let sightings: [SightingSnapshot]

    init(event: Event) {
        id = event.id
        date = event.date
        venue = event.venue
        watchLocation = event.watchLocation?.rawValue
        sightings = event.sightings.map(SightingSnapshot.init)
    }
}

struct SightingSnapshot: Equatable {
    let teamName: String?
    let teamSport: String?
    let firstName: String?
    let lastName: String?
    let playerNumber: String?

    init(sighting: JerseySighting) {
        teamName = sighting.team?.name
        teamSport = sighting.team?.sport
        firstName = sighting.firstName
        lastName = sighting.lastName
        playerNumber = sighting.playerNumber
    }
}

@MainActor
@Observable
final class StatsViewModel {
    private(set) var hasLoaded = false
    private(set) var availableYears: [Int] = []
    private(set) var filteredEvents: [Event] = []
    private(set) var totalGames = 0
    private(set) var totalSightings = 0
    private(set) var teamTotals: [(team: Team, count: Int)] = []
    private(set) var leagueTotals: [(sport: String, count: Int)] = []
    private(set) var watchLocationTotals: (stadium: Int, tv: Int) = (0, 0)
    private(set) var venueTotals: [(venue: String, count: Int)] = []
    private(set) var topPlayers: [(name: String, team: Team, playerNumber: String?, count: Int)] = []

    private var cacheKey: StatsCacheKey?

    func update(key: StatsCacheKey, events: [Event]) {
        guard key != cacheKey else { return }

        cacheKey = key
        let selectedYear = key.selectedYear
        let calendar = Calendar.current
        availableYears = Set(events.map { calendar.component(.year, from: $0.date) }).sorted().reversed()

        if let selectedYear {
            filteredEvents = events.filter { calendar.component(.year, from: $0.date) == selectedYear }
        } else {
            filteredEvents = events
        }

        totalGames = filteredEvents.count
        totalSightings = filteredEvents.reduce(0) { $0 + $1.sightings.count }

        let allSightings = filteredEvents.flatMap(\.sightings)
        let allTeams = allSightings.compactMap(\.team)

        let groupedTeams = Dictionary(grouping: allTeams) { $0.name }
        teamTotals = groupedTeams
            .map { (team: $0.value[0], count: $0.value.count) }
            .sorted { a, b in a.count > b.count || (a.count == b.count && a.team.name < b.team.name) }

        let groupedLeagues = Dictionary(grouping: allTeams) { $0.sport.uppercased() }
        leagueTotals = groupedLeagues
            .map { ($0.key, $0.value.count) }
            .sorted { a, b in a.count > b.count || (a.count == b.count && a.sport < b.sport) }

        var stadium = 0
        var tv = 0
        for event in filteredEvents {
            switch event.watchLocation {
            case .stadium, .none:
                stadium += event.sightings.count
            case .tv:
                tv += event.sightings.count
            }
        }
        watchLocationTotals = (stadium, tv)

        let groupedVenues = Dictionary(grouping: filteredEvents.compactMap(\.venue)) { $0 }
        let venueCounts: [(venue: String, count: Int)] = groupedVenues.map {
            (venue: $0.key, count: $0.value.count)
        }
        let sortedVenues = venueCounts.sorted { a, b in
            a.count > b.count || (a.count == b.count && a.venue < b.venue)
        }
        venueTotals = Array(sortedVenues.prefix(10))

        let playerSightings = allSightings.filter(\.isPlayerSighting)
        let groupedPlayers = Dictionary(grouping: playerSightings) {
            "\($0.team?.name ?? ""):\($0.displayName)"
        }
        topPlayers = Array(groupedPlayers
            .compactMap { (_, values) -> (name: String, team: Team, playerNumber: String?, count: Int)? in
                guard let first = values.first, let team = first.team else { return nil }
                return (first.displayName, team, first.playerNumber, values.count)
            }
            .sorted { a, b in a.count > b.count || (a.count == b.count && a.name < b.name) }
            .prefix(5))

        hasLoaded = true
    }
}
