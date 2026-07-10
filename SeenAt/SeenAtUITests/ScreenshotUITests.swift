import XCTest

final class ScreenshotUITests: XCTestCase {

    let screenshotsDir = "/Users/tonycardone/Documents/seen-at/screenshots"

    override func setUpWithError() throws {
        continueAfterFailure = true
        try FileManager.default.createDirectory(atPath: screenshotsDir, withIntermediateDirectories: true)
    }

    func testCaptureScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--seedData"]
        app.launch()

        sleep(8)

        // 1. HomeView — Games tab with seeded events
        capture("HomeView")

        // 2. Navigate to LiveTrackingView via first event button
        let eventBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Cardinals'")).firstMatch
        if eventBtn.waitForExistence(timeout: 5) {
            eventBtn.tap()
            sleep(4)
            capture("LiveTrackingView")
            let back = app.navigationBars.buttons.firstMatch
            if back.waitForExistence(timeout: 3) { back.tap() }
            sleep(2)
        }

        // 3. Stats tab
        app.tabBars.buttons["Stats"].tap()
        sleep(2)
        capture("StatsView")

        // 4. Settings tab
        app.tabBars.buttons["Settings"].tap()
        sleep(2)
        capture("SettingsView")

        // 5. Favorite Teams
        let fav = app.staticTexts["Favorite Teams"]
        if fav.waitForExistence(timeout: 3) {
            fav.firstMatch.tap()
            sleep(2)
            capture("FavoriteTeamsView")
        }
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
