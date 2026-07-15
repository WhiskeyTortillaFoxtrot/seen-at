import Foundation
import SwiftData

enum TeamSeedService {
    private static let hasSeededKey = "hasSeededTeams"

    @MainActor
    static func seedIfNeeded(modelContext: ModelContext) async {
        guard !UserDefaults.standard.bool(forKey: hasSeededKey) else { return }

        let descriptor = FetchDescriptor<Team>(predicate: #Predicate { $0.isBuiltIn == true })
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        let seededSports = Set(existing.map(\.sport))

        let leagueTeams: [(String, [Team])] = [
            ("mlb", MLBTeams.all),
            ("nba", NBATeams.all),
            ("nfl", NFLTeams.all),
            ("nhl", NHLTeams.all),
            ("lovb", LOVBTeams.all),
            ("mls", MLSTeams.all),
        ]

        for (sport, teams) in leagueTeams {
            if !seededSports.contains(sport) {
                for team in teams {
                    modelContext.insert(team)
                }
            }
        }

        if seededSports.count < leagueTeams.count {
            guard modelContext.saveAndLog("Failed to seed teams") else { return }
        }

        UserDefaults.standard.set(true, forKey: hasSeededKey)
    }
}
