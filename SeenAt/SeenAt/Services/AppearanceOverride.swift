import SwiftUI

/// Appearance override from Settings. `system` (the default) follows the device.
enum AppearanceOverride: String, Sendable {
    case system
    case light
    case dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    static var current: AppearanceOverride {
        guard let raw = UserDefaults.standard.string(forKey: AppPreferences.appearanceOverrideKey) else {
            return .system
        }
        return AppearanceOverride(rawValue: raw) ?? .system
    }
}
