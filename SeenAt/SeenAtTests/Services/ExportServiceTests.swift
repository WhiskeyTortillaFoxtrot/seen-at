import XCTest
@testable import SeenAt
import SwiftData

@MainActor
final class ExportServiceTests: XCTestCase {
    var container: ModelContainer!
    var context: ModelContext!

    override func setUp() {
        super.setUp()
        container = TestModelContainer.create()
        context = container.mainContext
    }

    override func tearDown() {
        container = nil
        context = nil
        super.tearDown()
    }

    func testGenerateSummaryWithSightings() {
        let event = TestDataFactory.makeEvent(title: "Home @ Away")
        context.insert(event)
        let team = TestDataFactory.makeTeam(name: "Test Team")
        context.insert(team)
        let sighting = TestDataFactory.makeSighting(team: team, firstName: "John", lastName: "Doe", event: event)
        context.insert(sighting)

        let summary = ExportService.generateSummary(for: event)
        XCTAssertTrue(summary.contains("Home @ Away"))
        XCTAssertTrue(summary.contains("1"))
        XCTAssertTrue(summary.contains("Test Team"))
        XCTAssertTrue(summary.contains("John Doe"))
    }

    func testGenerateSummaryEmptyEvent() {
        let event = TestDataFactory.makeEvent(title: "Empty Game")
        context.insert(event)

        let summary = ExportService.generateSummary(for: event)
        XCTAssertTrue(summary.contains("Empty Game"))
        XCTAssertTrue(summary.contains("0"))
    }

    func testGenerateAllDataCSV() {
        let event = TestDataFactory.makeEvent(title: "Test Event", date: Date(timeIntervalSince1970: 0))
        context.insert(event)
        let team = TestDataFactory.makeTeam(name: "Team")
        context.insert(team)
        let sighting = TestDataFactory.makeSighting(team: team, firstName: "Jane", lastName: "Doe", number: "99", event: event)
        context.insert(sighting)

        let csv = ExportService.generateAllDataCSV(context: context)
        XCTAssertTrue(csv.contains("Event Title"))
        XCTAssertTrue(csv.contains("Test Event"))
        XCTAssertTrue(csv.contains("Jane"))
        XCTAssertTrue(csv.contains("Doe"))
        XCTAssertTrue(csv.contains("99"))
    }

    func testGenerateAllDataCSVEmpty() {
        let csv = ExportService.generateAllDataCSV(context: context)
        let lines = csv.components(separatedBy: .newlines).filter { !$0.isEmpty }
        XCTAssertEqual(lines.count, 1)
        XCTAssertTrue(lines[0].contains("Event Title"))
    }

    func testGenerateCSVEscapesCommas() {
        let event = TestDataFactory.makeEvent(title: "Team A, Team B @ Team C")
        context.insert(event)
        let team = TestDataFactory.makeTeam(name: "Team")
        context.insert(team)
        let sighting = TestDataFactory.makeSighting(team: team, firstName: "John", lastName: "Doe", event: event)
        context.insert(sighting)

        let csv = ExportService.generateAllDataCSV(context: context)
        XCTAssertTrue(csv.contains("\"Team A, Team B @ Team C\""))
    }

    func testEscapeCSVPrefixesLeadingEquals() {
        let event = TestDataFactory.makeEvent(title: "=SUM(A1:A10)")
        context.insert(event)

        let csv = ExportService.generateAllDataCSV(context: context)
        XCTAssertTrue(csv.contains("'=SUM(A1:A10)"))
    }

    func testEscapeCSVPrefixesLeadingPlus() {
        let event = TestDataFactory.makeEvent(title: "+1+2")
        context.insert(event)

        let csv = ExportService.generateAllDataCSV(context: context)
        XCTAssertTrue(csv.contains("'+1+2"))
    }

    func testEscapeCSVPrefixesLeadingMinus() {
        let event = TestDataFactory.makeEvent(title: "-1+2")
        context.insert(event)

        let csv = ExportService.generateAllDataCSV(context: context)
        XCTAssertTrue(csv.contains("'-1+2"))
    }

    func testEscapeCSVPrefixesLeadingAt() {
        let event = TestDataFactory.makeEvent(title: "@SUM(1,2)")
        context.insert(event)

        let csv = ExportService.generateAllDataCSV(context: context)
        XCTAssertTrue(csv.contains("'\"@SUM(1,2)\""))
    }

    func testEscapeCSVHandlesFormulaWithCommas() {
        let event = TestDataFactory.makeEvent(title: "=SUM(1, 2)")
        context.insert(event)

        let csv = ExportService.generateAllDataCSV(context: context)
        XCTAssertTrue(csv.contains("'\"=SUM(1, 2)\""))
    }
}
