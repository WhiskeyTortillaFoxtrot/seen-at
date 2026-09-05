import UIKit

/// Central gate for haptic feedback. The toggle lives in Settings
/// (`AppPreferences.hapticsEnabledKey`); every generator call site routes
/// through `impact(_:)` so disabling haptics silences the whole app.
/// Defaults to on: `bool(forKey:)` returns false for unset keys, so the
/// stored object is checked to distinguish "never set" from "disabled".
enum Haptics {
    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: AppPreferences.hapticsEnabledKey) as? Bool ?? true
    }

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        guard isEnabled else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
