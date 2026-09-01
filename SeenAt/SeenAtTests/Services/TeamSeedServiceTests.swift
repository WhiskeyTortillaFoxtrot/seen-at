import XCTest
@testable import SeenAt
import SwiftData

@MainActor
final class TeamSeedServiceTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "seedVersion")
        container = TestModelContainer.create()
        context = container.mainContext
    }

    override func tearDown() {
        container = nil
        context = nil
        UserDefaults.standard.removeObject(forKey: "seedVersion")
        super.tearDown()
    }

    func testSeedsTeamsOnFirstLaunch() async {
        let beforeCount = try? context.fetchCount(FetchDescriptor<Team>())
        XCTAssertEqual(beforeCount, 0)

        await TeamSeedService.seedIfNeeded(modelContext: context)

        let afterCount = try? context.fetchCount(FetchDescriptor<Team>())
        XCTAssertEqual(afterCount, 191)
    }

    func testDoesNotReseed() async {
        await TeamSeedService.seedIfNeeded(modelContext: context)

        let manualTeam = TestDataFactory.makeTeam()
        context.insert(manualTeam)
        try? context.save()

        let countAfterManual = try? context.fetchCount(FetchDescriptor<Team>())
        XCTAssertEqual(countAfterManual, 192)

        await TeamSeedService.seedIfNeeded(modelContext: context)

        let countAfterSecondSeed = try? context.fetchCount(FetchDescriptor<Team>())
        XCTAssertEqual(countAfterSecondSeed, 192)
    }

    func testSeededTeamsAreBuiltIn() async {
        await TeamSeedService.seedIfNeeded(modelContext: context)

        let predicate = #Predicate<Team> { $0.isBuiltIn == true }
        let builtInCount = try? context.fetchCount(FetchDescriptor<Team>(predicate: predicate))
        XCTAssertEqual(builtInCount, 191)
    }

    func testSeedsAllCurrentWNBATeams() async throws {
        await TeamSeedService.seedIfNeeded(modelContext: context)

        let teams = try context.fetch(FetchDescriptor<Team>())
        let wnbaTeams = teams.filter { $0.sport == "wnba" }
        XCTAssertEqual(wnbaTeams.count, 15)
        XCTAssertEqual(Set(wnbaTeams.map(\.name)), Set(WNBATeams.all.map(\.name)))
    }

    func testSeededTeamsHaveCorrectNames() async throws {
        await TeamSeedService.seedIfNeeded(modelContext: context)

        let descriptor = FetchDescriptor<Team>(sortBy: [SortDescriptor(\.name)])
        let teams = try context.fetch(descriptor)

        XCTAssertEqual(teams.first?.name, "Anaheim Ducks")
        XCTAssertEqual(teams.last?.name, "Winnipeg Jets")
    }

    func testReseedsWhenSeedVersionIsOld() async {
        UserDefaults.standard.set(0, forKey: "seedVersion")

        await TeamSeedService.seedIfNeeded(modelContext: context)

        let count = try? context.fetchCount(FetchDescriptor<Team>())
        XCTAssertEqual(count, 191)
    }

    func testDoesNotReseedWhenCurrentVersion() async {
        await TeamSeedService.seedIfNeeded(modelContext: context)

        let beforeReseed = try? context.fetchCount(FetchDescriptor<Team>())
        XCTAssertEqual(beforeReseed, 191)

        await TeamSeedService.seedIfNeeded(modelContext: context)

        let afterReseed = try? context.fetchCount(FetchDescriptor<Team>())
        XCTAssertEqual(afterReseed, 191)
    }

    func testMigratesRenamedTeams() async throws {
        let oldA = Team(name: "Oakland Athletics", abbreviation: "OAK", sport: "mlb", isBuiltIn: true, primaryColorHex: "#003831", secondaryColorHex: "#EFB21E")
        let oldU = Team(name: "Utah Hockey Club", abbreviation: "UTA", sport: "nhl", isBuiltIn: true, primaryColorHex: "#71AFE5", secondaryColorHex: "#111111")
        context.insert(oldA)
        context.insert(oldU)
        try? context.save()

        UserDefaults.standard.set(0, forKey: "seedVersion")

        await TeamSeedService.seedIfNeeded(modelContext: context)

        let teams = try context.fetch(FetchDescriptor<Team>())
        let athletics = teams.first { $0.name == "Athletics" }
        let mammoth = teams.first { $0.name == "Utah Mammoth" }
        XCTAssertNotNil(athletics, "Oakland Athletics should be renamed to Athletics")
        XCTAssertNotNil(mammoth, "Utah Hockey Club should be renamed to Utah Mammoth")

        XCTAssertNil(teams.first { $0.name == "Oakland Athletics" }, "Old name Oakland Athletics should be gone")
        XCTAssertNil(teams.first { $0.name == "Utah Hockey Club" }, "Old name Utah Hockey Club should be gone")

        XCTAssertEqual(athletics?.abbreviation, "ATH", "Abbreviation should be updated from OAK to ATH")
    }

    func testReseedSyncsTeamColors() async throws {
        await TeamSeedService.seedIfNeeded(modelContext: context)

        let predicate = #Predicate<Team> { $0.name == "Indiana Fever" }
        let descriptor = FetchDescriptor<Team>(predicate: predicate)
        let seeded = try context.fetch(descriptor)
        let originalPrimary = seeded.first?.primaryColorHex
        let originalSecondary = seeded.first?.secondaryColorHex
        XCTAssertNotNil(originalPrimary)

        // Simulate an install whose stored colors drifted from the seed values.
        let fever = seeded.first!
        fever.primaryColorHex = "#000000"
        try? context.save()

        UserDefaults.standard.set(3, forKey: AppPreferences.seedVersionKey)

        await TeamSeedService.seedIfNeeded(modelContext: context)

        let refreshed = try context.fetch(descriptor)
        XCTAssertEqual(refreshed.first?.primaryColorHex, originalPrimary)
        XCTAssertEqual(refreshed.first?.secondaryColorHex, originalSecondary)
    }

    func testResetClearsSeedVersionAllowingReseed() async {
        await TeamSeedService.seedIfNeeded(modelContext: context)

        let countAfterSeed = try? context.fetchCount(FetchDescriptor<Team>())
        XCTAssertEqual(countAfterSeed, 191)

        UserDefaults.standard.removeObject(forKey: "seedVersion")

        await TeamSeedService.seedIfNeeded(modelContext: context)

        let countAfterReset = try? context.fetchCount(FetchDescriptor<Team>())
        XCTAssertEqual(countAfterReset, 191, "Re-seeding after reset should still produce all built-in teams")
        let storedVersion = UserDefaults.standard.integer(forKey: "seedVersion")
        XCTAssertGreaterThan(storedVersion, 0, "seedVersion should be set again after re-seeding")
    }

    func testSeedsMLSTeams() async {
        await TeamSeedService.seedIfNeeded(modelContext: context)

        let predicate = #Predicate<Team> { $0.sport == "mls" }
        let mlsTeams = try? context.fetch(FetchDescriptor<Team>(predicate: predicate))
        XCTAssertEqual(mlsTeams?.count, 30)
        XCTAssertTrue(mlsTeams?.contains(where: { $0.name == "LA Galaxy" }) == true)
        XCTAssertTrue(mlsTeams?.contains(where: { $0.name == "Seattle Sounders FC" }) == true)
    }

    func testSeedsNWSLTeams() async {
        await TeamSeedService.seedIfNeeded(modelContext: context)

        let predicate = #Predicate<Team> { $0.sport == "nwsl" }
        let nwslTeams = try? context.fetch(FetchDescriptor<Team>(predicate: predicate))
        XCTAssertEqual(nwslTeams?.count, 16)
        XCTAssertTrue(nwslTeams?.contains(where: { $0.name == "Gotham FC" }) == true)
        XCTAssertTrue(nwslTeams?.contains(where: { $0.name == "Washington Spirit" }) == true)
        XCTAssertTrue(nwslTeams?.contains(where: { $0.name == "Kansas City Current" }) == true)
        XCTAssertTrue(nwslTeams?.contains(where: { $0.abbreviation == "KC" }) == true)
    }
}
