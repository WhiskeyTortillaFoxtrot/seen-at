import XCTest
@testable import SeenAt
import SwiftData

final class DisplayPreferencesTests: XCTestCase {
    private let touchedKeys = [
        AppPreferences.appearanceOverrideKey,
        AppPreferences.hapticsEnabledKey,
        AppPreferences.defaultWatchLocationKey,
        AppPreferences.photoQualityKey,
        AppPreferences.liveActivityAutoEndKey,
        AppPreferences.notificationReminderMinutesKey,
    ]

    private var savedValues: [String: Any] = [:]

    override func setUp() {
        super.setUp()
        savedValues = [:]
        for key in touchedKeys {
            if let value = UserDefaults.standard.object(forKey: key) {
                savedValues[key] = value
            }
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    override func tearDown() {
        for key in touchedKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        for (key, value) in savedValues {
            UserDefaults.standard.set(value, forKey: key)
        }
        savedValues = [:]
        super.tearDown()
    }

    func testResettableKeysIncludeNewPreferences() {
        for key in touchedKeys {
            XCTAssertTrue(AppPreferences.resettableKeys.contains(key), "\(key) must reset with a fresh store")
        }
    }

    func testDiagnosticsSafeKeysIncludeOnlyNonSensitiveNewPreferences() {
        XCTAssertTrue(AppPreferences.diagnosticsSafeKeys.contains(AppPreferences.appearanceOverrideKey))
        XCTAssertTrue(AppPreferences.diagnosticsSafeKeys.contains(AppPreferences.hapticsEnabledKey))
        XCTAssertTrue(AppPreferences.diagnosticsSafeKeys.contains(AppPreferences.defaultWatchLocationKey))
        XCTAssertFalse(AppPreferences.diagnosticsSafeKeys.contains(AppPreferences.photoQualityKey))
        XCTAssertFalse(AppPreferences.diagnosticsSafeKeys.contains(AppPreferences.liveActivityAutoEndKey))
        XCTAssertFalse(AppPreferences.diagnosticsSafeKeys.contains(AppPreferences.notificationReminderMinutesKey))
    }

    func testHapticsDefaultsToEnabled() {
        XCTAssertTrue(Haptics.isEnabled)
        Haptics.impact(.light)
    }

    func testHapticsRespectsToggle() {
        UserDefaults.standard.set(false, forKey: AppPreferences.hapticsEnabledKey)
        XCTAssertFalse(Haptics.isEnabled)
        Haptics.impact(.heavy)
        UserDefaults.standard.set(true, forKey: AppPreferences.hapticsEnabledKey)
        XCTAssertTrue(Haptics.isEnabled)
    }

    func testPhotoQualityDefaultsToStandard() {
        XCTAssertEqual(PhotoQuality.current, .standard)
    }

    func testPhotoQualityFallsBackToStandardForUnknownValue() {
        UserDefaults.standard.set("ultra", forKey: AppPreferences.photoQualityKey)
        XCTAssertEqual(PhotoQuality.current, .standard)
    }

    func testPhotoQualityTiers() {
        XCTAssertEqual(PhotoQuality.low.maxDimension, 800)
        XCTAssertEqual(PhotoQuality.low.compressionQuality, 0.7, accuracy: 0.001)
        XCTAssertEqual(PhotoQuality.standard.maxDimension, 1200)
        XCTAssertEqual(PhotoQuality.standard.compressionQuality, 0.85, accuracy: 0.001)
        XCTAssertEqual(PhotoQuality.high.maxDimension, 2400)
        XCTAssertEqual(PhotoQuality.high.compressionQuality, 0.95, accuracy: 0.001)
    }

    func testPhotoQualityRoundTripsThroughDefaults() {
        UserDefaults.standard.set(PhotoQuality.high.rawValue, forKey: AppPreferences.photoQualityKey)
        XCTAssertEqual(PhotoQuality.current, .high)
    }

    func testAppearanceDefaultsToSystem() {
        XCTAssertEqual(AppearanceOverride.current, .system)
        XCTAssertNil(AppearanceOverride.current.colorScheme)
    }

    func testAppearanceFallsBackToSystemForUnknownValue() {
        UserDefaults.standard.set("neon", forKey: AppPreferences.appearanceOverrideKey)
        XCTAssertEqual(AppearanceOverride.current, .system)
    }

    func testAppearanceMapsToColorSchemes() {
        XCTAssertEqual(AppearanceOverride.light.colorScheme, .light)
        XCTAssertEqual(AppearanceOverride.dark.colorScheme, .dark)
    }

    func testWatchLocationFallsBackToStadiumForUnknownValue() {
        let parsed = WatchLocation(rawValue: "bogus") ?? .stadium
        XCTAssertEqual(parsed, .stadium)
        XCTAssertEqual(WatchLocation(rawValue: WatchLocation.tv.rawValue), .tv)
    }

    func testLiveActivityAutoEndDefaultsToEnabled() {
        XCTAssertTrue(StoreLauncher.liveActivityAutoEndEnabled())
    }

    func testLiveActivityAutoEndRespectsToggle() {
        UserDefaults.standard.set(false, forKey: AppPreferences.liveActivityAutoEndKey)
        XCTAssertFalse(StoreLauncher.liveActivityAutoEndEnabled())
    }
}
