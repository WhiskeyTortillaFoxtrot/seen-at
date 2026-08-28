import XCTest
import SwiftData
@testable import SeenAt

@MainActor
final class DiagnosticsServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() {
        super.setUp()
        container = TestModelContainer.create()
        context = container.mainContext
        DiagnosticsService.shared.reset()
        UserDefaults.standard.set(false, forKey: "com.seenat.diagnostics.crashWatch")
    }

    override func tearDown() {
        DiagnosticsService.shared.reset()
        UserDefaults.standard.removeObject(forKey: "com.seenat.diagnostics.crashWatch")
        context = nil
        container = nil
        super.tearDown()
    }

    func testLogAddsEntry() {
        DiagnosticsService.shared.log(category: "Test", level: .info, message: "hello")

        XCTAssertEqual(DiagnosticsService.shared.entryCount, 1)
    }

    func testLogEntryFields() {
        DiagnosticsService.shared.log(category: "Network", level: .warning, message: "timeout")

        let report = DiagnosticsService.shared.generateReport(context: context)
        XCTAssertTrue(report.contains("[WARNING]"))
        XCTAssertTrue(report.contains("[Network]"))
        XCTAssertTrue(report.contains("timeout"))
    }

    func testRingBufferTrimsWhenOverCapacity() {
        for i in 0..<2100 {
            DiagnosticsService.shared.log(category: "Test", level: .debug, message: "entry \(i)")
        }

        XCTAssertEqual(DiagnosticsService.shared.entryCount, 1900)
    }

    func testRingBufferKeepsNewestEntries() {
        for i in 0..<2100 {
            DiagnosticsService.shared.log(category: "Test", level: .debug, message: "entry \(i)")
        }

        let report = DiagnosticsService.shared.generateReport(context: context)
        XCTAssertTrue(report.contains("entry 2099"))
        XCTAssertFalse(report.contains("entry 0"))
    }

    func testReportContainsSystemInfoSection() {
        let report = DiagnosticsService.shared.generateReport(context: context)

        XCTAssertTrue(report.contains("=== System Info ==="))
        XCTAssertTrue(report.contains("App Version:"))
        XCTAssertTrue(report.contains("OS Version:"))
        XCTAssertTrue(report.contains("Device Model:"))
        XCTAssertFalse(report.contains("Device Identifier:"))
    }

    func testReportContainsSessionLogSection() {
        DiagnosticsService.shared.log(category: "Test", level: .info, message: "logged")

        let report = DiagnosticsService.shared.generateReport(context: context)

        XCTAssertTrue(report.contains("=== Session Log"))
        XCTAssertTrue(report.contains("logged"))
    }

    func testExportURLProducesWritableFile() throws {
        DiagnosticsService.shared.log(category: "Test", level: .info, message: "export test")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = try DiagnosticsService.shared.exportURL(context: context, destinationDirectory: directory)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertTrue(try String(contentsOf: url, encoding: .utf8).contains("export test"))
    }

    func testExportURLSurfacesWriteFailure() throws {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data().write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        XCTAssertThrowsError(try DiagnosticsService.shared.exportURL(context: context, destinationDirectory: fileURL)) { error in
            XCTAssertEqual((error as NSError).domain, NSCocoaErrorDomain)
        }
    }

    func testResetClearsEntries() {
        DiagnosticsService.shared.log(category: "Test", level: .info, message: "one")
        DiagnosticsService.shared.log(category: "Test", level: .info, message: "two")
        XCTAssertEqual(DiagnosticsService.shared.entryCount, 2)

        DiagnosticsService.shared.reset()

        XCTAssertEqual(DiagnosticsService.shared.entryCount, 0)
    }

    func testLevelOrdering() {
        XCTAssertLessThan(DiagnosticsService.Level.debug, .info)
        XCTAssertLessThan(DiagnosticsService.Level.info, .warning)
        XCTAssertLessThan(DiagnosticsService.Level.warning, .error)
    }

    func testCrashWatchFlagOnLaunch() {
        UserDefaults.standard.set(true, forKey: "com.seenat.diagnostics.crashWatch")

        DiagnosticsService.shared.appDidBecomeActive()

        let report = DiagnosticsService.shared.generateReport(context: context)
        XCTAssertTrue(report.contains("Previous launch terminated unexpectedly"))
    }

    func testCrashWatchClearedOnBackground() {
        DiagnosticsService.shared.appDidBecomeActive()
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "com.seenat.diagnostics.crashWatch"))

        DiagnosticsService.shared.appDidBackground()

        XCTAssertFalse(UserDefaults.standard.bool(forKey: "com.seenat.diagnostics.crashWatch"))
    }

    func testConcurrentLoggingDoesNotCrash() async {
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    // Escape this @MainActor test case so logging is exercised concurrently.
                    await Task.detached {
                        DiagnosticsService.shared.log(category: "Concurrent", level: .info, message: "entry \(i)")
                    }.value
                }
            }
        }
        XCTAssertGreaterThanOrEqual(DiagnosticsService.shared.entryCount, 100)
        XCTAssertLessThanOrEqual(DiagnosticsService.shared.entryCount, 2000)
    }

    func testCrashMessageAbsentOnCleanLaunch() {
        DiagnosticsService.shared.appDidBecomeActive()

        let report = DiagnosticsService.shared.generateReport(context: context)
        XCTAssertFalse(report.contains("Previous launch terminated unexpectedly"))
    }

    func testLogEntriesAppearReversedInReport() {
        DiagnosticsService.shared.log(category: "Test", level: .info, message: "aaaa-first")
        DiagnosticsService.shared.log(category: "Test", level: .info, message: "bbbb-second")
        DiagnosticsService.shared.log(category: "Test", level: .info, message: "cccc-third")

        let report = DiagnosticsService.shared.generateReport(context: context)
        let logSection = report.components(separatedBy: "=== Session Log").last ?? ""
        let firstIdx = logSection.range(of: "cccc-third")?.lowerBound
        let secondIdx = logSection.range(of: "bbbb-second")?.lowerBound
        let thirdIdx = logSection.range(of: "aaaa-first")?.lowerBound

        guard let firstIdx, let secondIdx, let thirdIdx else {
            return XCTFail("All log entries should be present in the report")
        }
        XCTAssertLessThan(firstIdx, secondIdx)
        XCTAssertLessThan(secondIdx, thirdIdx)
    }

    func testReportContainsEntityCounts() {
        let report = DiagnosticsService.shared.generateReport(context: context)

        XCTAssertTrue(report.contains("Entity Counts:"))
        XCTAssertTrue(report.contains("Events"))
        XCTAssertTrue(report.contains("Teams"))
        XCTAssertTrue(report.contains("Sightings"))
    }

    func testReportIncludesOnlyExplicitlySafePreferences() {
        let safeKey = AppPreferences.defaultSportKey
        let privateKey = AppPreferences.favoriteTeamsKey
        let defaults = UserDefaults.standard
        let originalSafeValue = defaults.object(forKey: safeKey)
        let originalPrivateValue = defaults.object(forKey: privateKey)
        defer {
            if let originalSafeValue {
                defaults.set(originalSafeValue, forKey: safeKey)
            } else {
                defaults.removeObject(forKey: safeKey)
            }
            if let originalPrivateValue {
                defaults.set(originalPrivateValue, forKey: privateKey)
            } else {
                defaults.removeObject(forKey: privateKey)
            }
        }

        defaults.set("diagnostics-safe-sport", forKey: safeKey)
        defaults.set("diagnostics-private-team", forKey: privateKey)

        let report = DiagnosticsService.shared.generateReport(context: context)

        XCTAssertTrue(report.contains("\(safeKey) = diagnostics-safe-sport"))
        XCTAssertFalse(report.contains(privateKey))
        XCTAssertFalse(report.contains("diagnostics-private-team"))
        XCTAssertFalse(AppPreferences.diagnosticsSafeKeys.contains(privateKey))
    }
}
