import XCTest
@testable import SeenAt
import SwiftData

@MainActor
final class TeamSeedServiceTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "hasSeededTeams")
        UserDefaults.standard.removeObject(forKey: "seedVersion")
        container = TestModelContainer.create()
        context = container.mainContext
    }

    override func tearDown() {
        container = nil
        context = nil
        UserDefaults.standard.removeObject(forKey: "hasSeededTeams")
        UserDefaults.standard.removeObject(forKey: "seedVersion")
        super.tearDown()
    }

    func testSeedsTeamsOnFirstLaunch() async {
        let beforeCount = try? context.fetchCount(FetchDescriptor<Team>())
        XCTAssertEqual(beforeCount, 0)

        await TeamSeedService.seedIfNeeded(modelContext: context)

        let afterCount = try? context.fetchCount(FetchDescriptor<Team>())
        XCTAssertEqual(afterCount, 160)
    }

    func testDoesNotReseed() async {
        await TeamSeedService.seedIfNeeded(modelContext: context)

        let manualTeam = TestDataFactory.makeTeam()
        context.insert(manualTeam)
        try? context.save()

        let countAfterManual = try? context.fetchCount(FetchDescriptor<Team>())
        XCTAssertEqual(countAfterManual, 161)

        await TeamSeedService.seedIfNeeded(modelContext: context)

        let countAfterSecondSeed = try? context.fetchCount(FetchDescriptor<Team>())
        XCTAssertEqual(countAfterSecondSeed, 161)
    }

    func testSeededTeamsAreBuiltIn() async {
        await TeamSeedService.seedIfNeeded(modelContext: context)

        let predicate = #Predicate<Team> { $0.isBuiltIn == true }
        let builtInCount = try? context.fetchCount(FetchDescriptor<Team>(predicate: predicate))
        XCTAssertEqual(builtInCount, 160)
    }

    func testSeededTeamsHaveCorrectNames() async {
        await TeamSeedService.seedIfNeeded(modelContext: context)

        let descriptor = FetchDescriptor<Team>(sortBy: [SortDescriptor(\.name)])
        let teams = try! context.fetch(descriptor)

        XCTAssertEqual(teams.first?.name, "Anaheim Ducks")
        XCTAssertEqual(teams.last?.name, "Winnipeg Jets")
    }

    func testReseedsWhenSeedVersionIsOld() async {
        UserDefaults.standard.set(true, forKey: "hasSeededTeams")
        UserDefaults.standard.set(0, forKey: "seedVersion")

        await TeamSeedService.seedIfNeeded(modelContext: context)

        let count = try? context.fetchCount(FetchDescriptor<Team>())
        XCTAssertEqual(count, 160)
    }

    func testDoesNotReseedWhenCurrentVersion() async {
        await TeamSeedService.seedIfNeeded(modelContext: context)

        let beforeReseed = try? context.fetchCount(FetchDescriptor<Team>())
        XCTAssertEqual(beforeReseed, 160)

        await TeamSeedService.seedIfNeeded(modelContext: context)

        let afterReseed = try? context.fetchCount(FetchDescriptor<Team>())
        XCTAssertEqual(afterReseed, 160)
    }

    func testMigratesRenamedTeams() async {
        let oldA = Team(name: "Oakland Athletics", abbreviation: "OAK", sport: "mlb", isBuiltIn: true, primaryColorHex: "#003831", secondaryColorHex: "#EFB21E")
        let oldU = Team(name: "Utah Hockey Club", abbreviation: "UTA", sport: "nhl", isBuiltIn: true, primaryColorHex: "#71AFE5", secondaryColorHex: "#111111")
        context.insert(oldA)
        context.insert(oldU)
        try? context.save()

        UserDefaults.standard.set(true, forKey: "hasSeededTeams")
        UserDefaults.standard.set(0, forKey: "seedVersion")

        await TeamSeedService.seedIfNeeded(modelContext: context)

        let teams = try! context.fetch(FetchDescriptor<Team>())
        let athletics = teams.first { $0.name == "Athletics" }
        let mammoth = teams.first { $0.name == "Utah Mammoth" }
        XCTAssertNotNil(athletics, "Oakland Athletics should be renamed to Athletics")
        XCTAssertNotNil(mammoth, "Utah Hockey Club should be renamed to Utah Mammoth")
    }

    func testSeedsMLSTeams() async {
        await TeamSeedService.seedIfNeeded(modelContext: context)

        let predicate = #Predicate<Team> { $0.sport == "mls" }
        let mlsTeams = try? context.fetch(FetchDescriptor<Team>(predicate: predicate))
        XCTAssertEqual(mlsTeams?.count, 30)
        XCTAssertTrue(mlsTeams?.contains(where: { $0.name == "LA Galaxy" }) == true)
        XCTAssertTrue(mlsTeams?.contains(where: { $0.name == "Seattle Sounders FC" }) == true)
    }
}
