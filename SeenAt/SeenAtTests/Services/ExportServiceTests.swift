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

    /// Parses RFC 4180 CSV (quoted fields, doubled quotes, comma/newline separators) so
    /// assertions check real cell values instead of raw substrings.
    private func parseCSV(_ csv: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var index = csv.startIndex

        while index < csv.endIndex {
            let character = csv[index]
            let next = csv.index(after: index)

            if inQuotes {
                if character == "\"" {
                    if next < csv.endIndex, csv[next] == "\"" {
                        field.append("\"")
                        index = csv.index(after: next)
                    } else {
                        inQuotes = false
                        index = next
                    }
                } else {
                    field.append(character)
                    index = next
                }
            } else if character == "\"" {
                inQuotes = true
                index = next
            } else if character == "," {
                row.append(field)
                field = ""
                index = next
            } else if character == "\n" || character == "\r" {
                row.append(field)
                rows.append(row)
                row = []
                field = ""
                index = next
            } else {
                field.append(character)
                index = next
            }
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
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

    func testGenerateAllDataCSV() throws {
        let event = TestDataFactory.makeEvent(title: "Test Event", date: Date(timeIntervalSince1970: 0))
        context.insert(event)
        let team = TestDataFactory.makeTeam(name: "Team")
        context.insert(team)
        let sighting = TestDataFactory.makeSighting(team: team, firstName: "Jane", lastName: "Doe", number: "99", event: event)
        context.insert(sighting)

        let rows = parseCSV(try ExportService.generateAllDataCSV(context: context))
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[0].count, 9)
        XCTAssertEqual(rows[0][0], "Event Title")
        XCTAssertEqual(rows[1][0], "Test Event")
        XCTAssertEqual(rows[1][5], "Team")
        XCTAssertEqual(rows[1][6], "Jane")
        XCTAssertEqual(rows[1][7], "Doe")
        XCTAssertEqual(rows[1][8], "99")
    }

    func testGenerateAllDataCSVEmpty() throws {
        let rows = parseCSV(try ExportService.generateAllDataCSV(context: context))
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].count, 9)
        XCTAssertEqual(rows[0].first, "Event Title")
    }

    func testGenerateCSVEscapesCommas() throws {
        let event = TestDataFactory.makeEvent(title: "Team A, Team B @ Team C")
        context.insert(event)
        let team = TestDataFactory.makeTeam(name: "Team")
        context.insert(team)
        let sighting = TestDataFactory.makeSighting(team: team, firstName: "John", lastName: "Doe", event: event)
        context.insert(sighting)

        let rows = parseCSV(try ExportService.generateAllDataCSV(context: context))
        XCTAssertEqual(rows.count, 2)
        XCTAssertEqual(rows[1].count, 9)
        XCTAssertEqual(rows[1][0], "Team A, Team B @ Team C")
    }

    func testEscapeCSVPrefixesLeadingEquals() throws {
        let event = TestDataFactory.makeEvent(title: "=SUM(A1:A10)")
        context.insert(event)

        let rows = parseCSV(try ExportService.generateAllDataCSV(context: context))
        XCTAssertEqual(rows[1][0], "'=SUM(A1:A10)")
    }

    func testEscapeCSVPrefixesLeadingPlus() throws {
        let event = TestDataFactory.makeEvent(title: "+1+2")
        context.insert(event)

        let rows = parseCSV(try ExportService.generateAllDataCSV(context: context))
        XCTAssertEqual(rows[1][0], "'+1+2")
    }

    func testEscapeCSVPrefixesLeadingMinus() throws {
        let event = TestDataFactory.makeEvent(title: "-1+2")
        context.insert(event)

        let rows = parseCSV(try ExportService.generateAllDataCSV(context: context))
        XCTAssertEqual(rows[1][0], "'-1+2")
    }

    func testEscapeCSVPrefixesLeadingAt() throws {
        let event = TestDataFactory.makeEvent(title: "@SUM(1,2)")
        context.insert(event)

        let rows = parseCSV(try ExportService.generateAllDataCSV(context: context))
        XCTAssertEqual(rows[1][0], "'@SUM(1,2)")
        XCTAssertEqual(rows[1].count, 9)
    }

    func testEscapeCSVHandlesFormulaWithCommas() throws {
        let event = TestDataFactory.makeEvent(title: "=SUM(1, 2)")
        context.insert(event)

        // The formula prefix must land inside the quotes: a standards-compliant parser
        // reads back a single cell whose value is "'=SUM(1, 2)", with no column shift.
        let rows = parseCSV(try ExportService.generateAllDataCSV(context: context))
        XCTAssertEqual(rows[1][0], "'=SUM(1, 2)")
        XCTAssertEqual(rows[1].count, 9)
    }

    func testEscapeCSVDoublesEmbeddedQuotes() throws {
        let event = TestDataFactory.makeEvent(title: "\"Quotes\", here")
        context.insert(event)

        let rows = parseCSV(try ExportService.generateAllDataCSV(context: context))
        XCTAssertEqual(rows[1][0], "\"Quotes\", here")
        XCTAssertEqual(rows[1].count, 9)
    }
}
