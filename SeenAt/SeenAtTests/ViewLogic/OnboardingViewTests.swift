import XCTest
@testable import SeenAt

final class OnboardingViewTests: XCTestCase {

    private let hasSeenKey = "hasSeenOnboarding"
    private let favoriteTeamsKey = "favoriteTeams"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: hasSeenKey)
        UserDefaults.standard.removeObject(forKey: favoriteTeamsKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: hasSeenKey)
        UserDefaults.standard.removeObject(forKey: favoriteTeamsKey)
        super.tearDown()
    }

    func testHasSeenOnboardingDefaultsToFalse() {
        XCTAssertFalse(UserDefaults.standard.bool(forKey: hasSeenKey))
    }

    func testFavoriteTeamsDefaultsToEmpty() {
        let value = UserDefaults.standard.string(forKey: favoriteTeamsKey)
        XCTAssertNil(value)
    }

    func testFavoriteCountFromEmptyString() {
        let count = favoriteCount(from: "")
        XCTAssertEqual(count, 0)
    }

    func testFavoriteCountFromSingleTeam() {
        let count = favoriteCount(from: "Yankees")
        XCTAssertEqual(count, 1)
    }

    func testFavoriteCountFromMultipleTeams() {
        let count = favoriteCount(from: "Yankees,Cubs,Dodgers")
        XCTAssertEqual(count, 3)
    }

    func testFavoriteCountFromTrailingComma() {
        let count = favoriteCount(from: "Yankees,")
        XCTAssertEqual(count, 1)
    }

    func testMarkOnboardingSeen() {
        XCTAssertFalse(UserDefaults.standard.bool(forKey: hasSeenKey))
        UserDefaults.standard.set(true, forKey: hasSeenKey)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: hasSeenKey))
    }

    func testSetFavoriteTeams() {
        let teams = "Cubs,Yankees"
        UserDefaults.standard.set(teams, forKey: favoriteTeamsKey)
        let stored = UserDefaults.standard.string(forKey: favoriteTeamsKey)
        XCTAssertEqual(stored, teams)
    }

    func testClearFavoriteTeams() {
        UserDefaults.standard.set("Cubs,Yankees", forKey: favoriteTeamsKey)
        UserDefaults.standard.removeObject(forKey: favoriteTeamsKey)
        let stored = UserDefaults.standard.string(forKey: favoriteTeamsKey)
        XCTAssertNil(stored)
    }

    private func favoriteCount(from string: String) -> Int {
        string.split(separator: ",").count
    }
}
