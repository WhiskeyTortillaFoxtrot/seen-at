import Foundation

enum AppPreferences {
    static let seedVersionKey = "seedVersion"
    static let favoriteTeamsKey = "favoriteTeams"
    static let legacyFavoriteTeamKey = "favoriteTeam"
    static let hasSeenOnboardingKey = "hasSeenOnboarding"
    static let defaultSportKey = "defaultSport"
    static let appearanceOverrideKey = "appearanceOverride"
    static let hapticsEnabledKey = "hapticsEnabled"
    static let defaultWatchLocationKey = "defaultWatchLocation"
    static let photoQualityKey = "photoQuality"
    static let liveActivityAutoEndKey = "liveActivityAutoEnd"
    static let notificationReminderMinutesKey = "notificationReminderMinutes"

    static let resettableKeys: Set<String> = [
        seedVersionKey,
        favoriteTeamsKey,
        legacyFavoriteTeamKey,
        hasSeenOnboardingKey,
        defaultSportKey,
        appearanceOverrideKey,
        hapticsEnabledKey,
        defaultWatchLocationKey,
        photoQualityKey,
        liveActivityAutoEndKey,
        notificationReminderMinutesKey,
    ]

    /// Preferences explicitly approved for inclusion in a user-shareable diagnostics report.
    /// Keep this separate from reset behavior so new preferences are private by default.
    static let diagnosticsSafeKeys: Set<String> = [
        seedVersionKey,
        hasSeenOnboardingKey,
        defaultSportKey,
        appearanceOverrideKey,
        hapticsEnabledKey,
        defaultWatchLocationKey,
    ]

    static func resetForFreshStore() {
        // Keep this list aligned with app preferences and their @AppStorage declarations.
        for key in resettableKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
