import Foundation
import SwiftData

enum TeamSeedService {
    private static let currentSeedVersion = 3

    @MainActor
    static func seedIfNeeded(modelContext: ModelContext) async {
        let storedVersion = UserDefaults.standard.integer(forKey: AppPreferences.seedVersionKey)
        guard storedVersion < currentSeedVersion else { return }

        let builtInPredicate = #Predicate<Team> { $0.isBuiltIn == true }
        let existing = (try? modelContext.fetch(FetchDescriptor<Team>(predicate: builtInPredicate))) ?? []

        var didMutate = false
        didMutate = migrateNames(in: modelContext, existing: existing) || didMutate

        let currentNames = Set(existing.map(\.name))

        let leagueTeams: [(String, [Team])] = [
            ("mlb", MLBTeams.all),
            ("nba", NBATeams.all),
            ("wnba", WNBATeams.all),
            ("nfl", NFLTeams.all),
            ("nhl", NHLTeams.all),
            ("lovb", LOVBTeams.all),
            ("mls", MLSTeams.all),
            ("nwsl", NWSLTeams.all),
        ]

        for (_, teams) in leagueTeams {
            for team in teams {
                if !currentNames.contains(team.name) {
                    modelContext.insert(team)
                    didMutate = true
                }
            }
        }

        if didMutate {
            guard modelContext.saveAndLog("Failed to seed teams") else { return }
        }

        UserDefaults.standard.set(currentSeedVersion, forKey: AppPreferences.seedVersionKey)
    }

    @MainActor
    private static func migrateNames(in modelContext: ModelContext, existing: [Team]) -> Bool {
        let renames: [(String, String, String?)] = [
            ("Oakland Athletics", "Athletics", "ATH"),
            ("Utah Hockey Club", "Utah Mammoth", nil),
        ]

        var didRename = false
        for (oldName, newName, newAbbreviation) in renames {
            if let team = existing.first(where: { $0.name == oldName }) {
                team.name = newName
                if let newAbbreviation {
                    team.abbreviation = newAbbreviation
                }
                didRename = true
            }
        }
        return didRename
    }
}
