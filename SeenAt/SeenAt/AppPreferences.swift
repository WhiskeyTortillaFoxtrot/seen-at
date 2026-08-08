import Foundation

enum AppPreferences {
    static let seedVersionKey = "seedVersion"
    static let favoriteTeamsKey = "favoriteTeams"
    static let legacyFavoriteTeamKey = "favoriteTeam"
    static let hasSeenOnboardingKey = "hasSeenOnboarding"
    static let defaultSportKey = "defaultSport"

    static let resettableKeys: Set<String> = [
        seedVersionKey,
        favoriteTeamsKey,
        legacyFavoriteTeamKey,
        hasSeenOnboardingKey,
        defaultSportKey,
    ]

    static func resetForFreshStore() {
        // Keep this list aligned with app preferences and their @AppStorage declarations.
        for key in resettableKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
