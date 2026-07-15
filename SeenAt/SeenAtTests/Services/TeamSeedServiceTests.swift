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
        container = TestModelContainer.create()
        context = container.mainContext
    }

    override func tearDown() {
        container = nil
        context = nil
        UserDefaults.standard.removeObject(forKey: "hasSeededTeams")
        super.tearDown()
    }

    func testSeedsTeamsOnFirstLaunch() async {
        let beforeCount = try? context.fetchCount(FetchDescriptor<Team>())
        XCTAssertEqual(beforeCount, 0)

        await TeamSeedService.seedIfNeeded(modelContext: context)

        let afterCount = try? context.fetchCount(FetchDescriptor<Team>())
        XCTAssertEqual(afterCount, 158)
    }

    func testDoesNotReseed() async {
        await TeamSeedService.seedIfNeeded(modelContext: context)

        let manualTeam = TestDataFactory.makeTeam()
        context.insert(manualTeam)
        try? context.save()

        let countAfterManual = try? context.fetchCount(FetchDescriptor<Team>())
        XCTAssertEqual(countAfterManual, 159)

        await TeamSeedService.seedIfNeeded(modelContext: context)

        let countAfterSecondSeed = try? context.fetchCount(FetchDescriptor<Team>())
        XCTAssertEqual(countAfterSecondSeed, 159)
    }

    func testSeededTeamsAreBuiltIn() async {
        await TeamSeedService.seedIfNeeded(modelContext: context)

        let predicate = #Predicate<Team> { $0.isBuiltIn == true }
        let builtInCount = try? context.fetchCount(FetchDescriptor<Team>(predicate: predicate))
        XCTAssertEqual(builtInCount, 158)
    }

    func testSeededTeamsHaveCorrectNames() async {
        await TeamSeedService.seedIfNeeded(modelContext: context)

        let descriptor = FetchDescriptor<Team>(sortBy: [SortDescriptor(\.name)])
        let teams = try! context.fetch(descriptor)

        XCTAssertEqual(teams.first?.name, "Anaheim Ducks")
        XCTAssertEqual(teams.last?.name, "Winnipeg Jets")
    }

    func testSeedsMLSTeams() async {
        await TeamSeedService.seedIfNeeded(modelContext: context)

        let predicate = #Predicate<Team> { $0.sport == "mls" }
        let mlsTeams = try? context.fetch(FetchDescriptor<Team>(predicate: predicate))
        XCTAssertEqual(mlsTeams?.count, 28)
        XCTAssertTrue(mlsTeams?.contains(where: { $0.name == "LA Galaxy" }) == true)
        XCTAssertTrue(mlsTeams?.contains(where: { $0.name == "Seattle Sounders FC" }) == true)
    }
}
