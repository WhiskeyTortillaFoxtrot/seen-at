import XCTest

@MainActor
final class ScreenshotUITests: XCTestCase {

    private let pollInterval: TimeInterval = 0.25
    private let screenLoadTimeout: TimeInterval = 30

    let screenshotsDir: URL = {
        if let dir = ProcessInfo.processInfo.environment["PROJECT_DIR"] {
            return URL(fileURLWithPath: dir)
                .deletingLastPathComponent()
                .appendingPathComponent("screenshots", isDirectory: true)
        }
        return URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appendingPathComponent("screenshots", isDirectory: true)
    }()

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: screenshotsDir, withIntermediateDirectories: true)
    }

    func testCaptureScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--resetData", "--seedData"]
        app.launch()

        let skip = app.buttons["Skip"]
        if skip.waitForExistence(timeout: 15) {
            guard tapWhenHittable(skip) else {
                XCTFail("Onboarding Skip button did not become hittable")
                return
            }
        }

        let gamesNavigationBar = app.navigationBars["SeenAt"]
        let todayBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Cardinals'")).firstMatch
        guard gamesNavigationBar.waitForExistence(timeout: 15),
              todayBtn.waitForExistence(timeout: 15),
              waitUntilHittable(todayBtn, timeout: 15) else {
            XCTFail("Games screen did not load")
            return
        }

        // 1. HomeView — Games tab with seeded events
        try capture("HomeView")

        // 2. Navigate to LiveTrackingView via first Today event
        let liveTrackingTitle = app.staticTexts["St. Louis Cardinals @ Chicago Cubs"]
        guard todayBtn.waitForExistence(timeout: 15),
              tapAndWaitFor(todayBtn, destination: liveTrackingTitle, sourceScreen: gamesNavigationBar) else {
            XCTFail("Seeded Cardinals event did not become tappable")
            return
        }
        try capture("LiveTrackingView")
        let liveTrackingBack = app.navigationBars.buttons["SeenAt"]
        guard tapWhenHittable(liveTrackingBack), gamesNavigationBar.waitForExistence(timeout: 10) else {
            XCTFail("Could not return from Live Tracking screen")
            return
        }

        // 3. Navigate to EventSummaryView via a Recent event
        let pastBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Giants'")).firstMatch
        let eventSummaryTitle = app.staticTexts["San Francisco Giants @ Los Angeles Dodgers"]
        guard pastBtn.waitForExistence(timeout: 10),
              tapAndWaitFor(pastBtn, destination: eventSummaryTitle, sourceScreen: gamesNavigationBar) else {
            XCTFail("Seeded Giants event did not become tappable")
            return
        }
        guard app.staticTexts["Los Angeles Dodgers"].waitForExistence(timeout: 15),
              app.staticTexts["By Team"].waitForExistence(timeout: 15),
              app.staticTexts["By Player"].waitForExistence(timeout: 15) else {
            XCTFail("Event Summary screen did not load")
            return
        }
        // 4. Event Summary
        try capture("EventSummaryView")

        // 5. Stats tab
        let statsTab = app.tabBars.buttons["Stats"]
        guard tapWhenHittable(statsTab),
              app.navigationBars["Stats"].waitForExistence(timeout: screenLoadTimeout),
              app.staticTexts["St. Louis Cardinals"].waitForExistence(timeout: screenLoadTimeout) else {
            XCTFail("Stats screen did not load")
            return
        }
        try capture("StatsView")

        // 6. Settings tab
        let settingsTab = app.tabBars.buttons["Settings"]
        let favoriteTeams = app.staticTexts["Favorite Teams"].firstMatch
        guard tapWhenHittable(settingsTab), favoriteTeams.waitForExistence(timeout: screenLoadTimeout) else {
            XCTFail("Settings screen did not load")
            return
        }
        try capture("SettingsView")

        // 7. Favorite Teams
        guard tapWhenHittable(favoriteTeams) else {
            XCTFail("Favorite Teams screen did not become tappable")
            return
        }
        guard app.navigationBars["Favorite Teams"].waitForExistence(timeout: screenLoadTimeout),
              app.buttons["MLB"].waitForExistence(timeout: screenLoadTimeout) else {
            XCTFail("Favorite Teams screen did not load")
            return
        }
        try capture("FavoriteTeamsView")
    }

    private func tapWhenHittable(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        guard waitUntilHittable(element, timeout: timeout) else { return false }
        element.tap()
        return true
    }

    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists && element.isHittable {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
        }
        return false
    }

    private func tapAndWaitFor(
        _ trigger: XCUIElement,
        destination: XCUIElement,
        sourceScreen: XCUIElement,
        timeout: TimeInterval = 15
    ) -> Bool {
        guard waitUntilHittable(trigger, timeout: timeout) else { return false }
        trigger.tap()
        var retryCount = 0
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if destination.exists {
                return true
            }
            if retryCount == 0,
               sourceScreen.exists && sourceScreen.isHittable,
               trigger.exists && trigger.isHittable {
                trigger.tap()
                retryCount = 1
            }
            RunLoop.current.run(until: Date().addingTimeInterval(pollInterval))
        }
        return destination.exists
    }

    private func capture(_ name: String) throws {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let url = screenshotsDir.appendingPathComponent(name).appendingPathExtension("png")
        try screenshot.pngRepresentation.write(to: url)
    }
}
