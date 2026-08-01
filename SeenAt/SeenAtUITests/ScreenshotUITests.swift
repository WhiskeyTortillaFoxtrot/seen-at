import XCTest

final class ScreenshotUITests: XCTestCase {

    let screenshotsDir: String = {
        if let dir = ProcessInfo.processInfo.environment["PROJECT_DIR"] {
            return (dir as NSString).appendingPathComponent("../screenshots")
        }
        return NSHomeDirectory() + "/screenshots"
    }()

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(atPath: screenshotsDir, withIntermediateDirectories: true)
    }

    func testCaptureScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--resetData", "--seedData"]
        app.launch()

        let skip = app.buttons["Skip"]
        if skip.waitForExistence(timeout: 2) {
            guard tapWhenHittable(skip) else {
                XCTFail("Onboarding Skip button did not become hittable")
                return
            }
        }

        let gamesNavigationBar = app.navigationBars["SeenAt"]
        guard gamesNavigationBar.waitForExistence(timeout: 15) else {
            XCTFail("Games screen did not load")
            return
        }

        // 1. HomeView — Games tab with seeded events
        capture("HomeView")

        // 2. Navigate to LiveTrackingView via first Today event
        let todayBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Cardinals'")).firstMatch
        guard todayBtn.waitForExistence(timeout: 15), tapWhenHittable(todayBtn) else {
            XCTFail("Seeded Cardinals event did not become tappable")
            return
        }
        guard app.staticTexts["St. Louis Cardinals @ Chicago Cubs"].waitForExistence(timeout: 15) else {
            XCTFail("Live Tracking screen did not load")
            return
        }
        capture("LiveTrackingView")
        let liveTrackingBack = app.navigationBars.buttons.firstMatch
        guard tapWhenHittable(liveTrackingBack), gamesNavigationBar.waitForExistence(timeout: 10) else {
            XCTFail("Could not return from Live Tracking screen")
            return
        }

        // 3. Navigate to EventSummaryView via a Recent event
        let pastBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Packers'")).firstMatch
        guard pastBtn.waitForExistence(timeout: 10), tapWhenHittable(pastBtn) else {
            XCTFail("Seeded Packers event did not become tappable")
            return
        }
        guard app.staticTexts["Green Bay Packers @ Chicago Bears"].waitForExistence(timeout: 15) else {
            XCTFail("Event Summary screen did not load")
            return
        }
        capture("EventSummaryView")
        let summaryBack = app.navigationBars.buttons.firstMatch
        guard tapWhenHittable(summaryBack), gamesNavigationBar.waitForExistence(timeout: 10) else {
            XCTFail("Could not return from Event Summary screen")
            return
        }

        // 5. Stats tab
        let statsTab = app.tabBars.buttons["Stats"]
        guard tapWhenHittable(statsTab), app.navigationBars["Stats"].waitForExistence(timeout: 10) else {
            XCTFail("Stats screen did not load")
            return
        }
        capture("StatsView")

        // 6. Settings tab
        let settingsTab = app.tabBars.buttons["Settings"]
        let favoriteTeams = app.staticTexts["Favorite Teams"].firstMatch
        guard tapWhenHittable(settingsTab), favoriteTeams.waitForExistence(timeout: 10) else {
            XCTFail("Settings screen did not load")
            return
        }
        capture("SettingsView")

        // 7. Favorite Teams
        guard tapWhenHittable(favoriteTeams) else {
            XCTFail("Favorite Teams screen did not become tappable")
            return
        }
        guard app.navigationBars["Favorite Teams"].waitForExistence(timeout: 10) else {
            XCTFail("Favorite Teams screen did not load")
            return
        }
        capture("FavoriteTeamsView")
    }

    private func tapWhenHittable(_ element: XCUIElement, timeout: TimeInterval = 10) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists && element.isHittable {
                element.tap()
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return false
    }

    private func capture(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let url = URL(fileURLWithPath: "\(screenshotsDir)/\(name).png")
        try? screenshot.pngRepresentation.write(to: url)
    }
}
