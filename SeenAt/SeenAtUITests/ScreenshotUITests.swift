import XCTest

final class ScreenshotUITests: XCTestCase {

    let screenshotsDir = "/Users/tonycardone/Documents/seen-at/screenshots"

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(atPath: screenshotsDir, withIntermediateDirectories: true)
    }

    func testCaptureScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--seedData"]
        app.launch()

        // Wait for seed data to appear
        XCTAssert(app.staticTexts["Cubs @ Cardinals"].waitForExistence(timeout: 10),
                  "Seed data did not appear")

        // 1. HomeView — Games tab
        capture("HomeView")

        // 2. Tap first Today event → LiveTrackingView
        app.staticTexts["Cubs @ Cardinals"].tap()
        XCTAssert(app.navigationBars["Live Tracking"].waitForExistence(timeout: 5),
                  "Live Tracking view did not appear")
        capture("LiveTrackingView")

        // 3. Back to HomeView
        app.navigationBars.buttons.firstMatch.tap()

        // 4. Tap first Recent event → EventSummaryView
        app.staticTexts["Packers @ Bears"].firstMatch.tap()
        XCTAssert(app.staticTexts["Total Jerseys Seen"].waitForExistence(timeout: 5),
                  "EventSummaryView did not appear")
        capture("EventSummaryView")

        // 5. Back to HomeView
        app.navigationBars.buttons.firstMatch.tap()

        // 6. Stats tab
        app.tabBars.buttons["Stats"].tap()
        XCTAssert(app.staticTexts["Games Tracked"].waitForExistence(timeout: 5),
                  "StatsView did not appear")
        capture("StatsView")

        // 7. Settings tab
        app.tabBars.buttons["Settings"].tap()
        XCTAssert(app.staticTexts["Settings"].waitForExistence(timeout: 5))
        capture("SettingsView")

        // 8. Favorite Teams
        app.staticTexts["Favorite Teams"].firstMatch.tap()
        XCTAssert(app.staticTexts["Favorite Teams"].waitForExistence(timeout: 5))
        capture("FavoriteTeamsView")
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
