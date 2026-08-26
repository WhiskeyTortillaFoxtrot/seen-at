import Foundation
import SwiftData
import UIKit

// Thread safety is manually managed via NSLock on the entries array.
// UserDefaults.standard is thread-safe by design, so it needs no lock.
final class DiagnosticsService: @unchecked Sendable {
    static let shared = DiagnosticsService()

    private var entries: [Entry] = []
    private let lock = NSLock()
    private let maxEntries = 2000
    private let trimCount = 200

    private init() {}

    struct Entry {
        let id: UUID
        let date: Date
        let category: String
        let level: Level
        let message: String
        let file: String
        let line: Int
    }

    enum Level: String, Comparable {
        case debug
        case info
        case warning
        case error

        static func < (lhs: Level, rhs: Level) -> Bool {
            let order: [Level: Int] = [.debug: 0, .info: 1, .warning: 2, .error: 3]
            return (order[lhs] ?? 0) < (order[rhs] ?? 0)
        }
    }

    private let minLogLevel: Level = {
#if DEBUG
        .debug
#else
        .info
#endif
    }()

    func log(category: String, level: Level, message: String, file: String = #file, line: Int = #line) {
        guard level >= minLogLevel else { return }
        lock.withLock {
            entries.append(Entry(
                id: UUID(),
                date: Date(),
                category: category,
                level: level,
                message: message,
                file: file,
                line: line
            ))
            if entries.count > maxEntries {
                entries.removeFirst(trimCount)
            }
        }
    }

    func appDidBecomeActive() {
        let crashed = UserDefaults.standard.bool(forKey: crashWatchKey)
        if crashed {
            log(category: "App", level: .error, message: "Previous launch terminated unexpectedly (possible crash)")
        }
        UserDefaults.standard.set(true, forKey: crashWatchKey)
    }

    func appDidBackground() {
        UserDefaults.standard.set(false, forKey: crashWatchKey)
    }

    @MainActor
    func generateReport(context: ModelContext) -> String {
        var report = ""

        report += "=== System Info ===\n"
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        report += "App Version: \(appVersion) (\(buildVersion))\n"
        report += "OS Version: \(UIDevice.current.systemVersion)\n"
        report += "Device Model: \(UIDevice.current.model)\n"

        let storeURL = StoreBackupService.defaultStoreURL()
        if let attrs = try? FileManager.default.attributesOfItem(atPath: storeURL.path),
           let fileSize = attrs[.size] as? Int64 {
            report += "Store File Size: \(byteCountFormatter.string(fromByteCount: fileSize))\n"
        } else {
            report += "Store File Size: unavailable\n"
        }

        let eventCount: String = {
            guard let count = try? context.fetch(FetchDescriptor<Event>()).count else { return "?" }
            return "\(count)"
        }()
        let teamCount: String = {
            guard let count = try? context.fetch(FetchDescriptor<Team>()).count else { return "?" }
            return "\(count)"
        }()
        let sightingCount: String = {
            guard let count = try? context.fetch(FetchDescriptor<JerseySighting>()).count else { return "?" }
            return "\(count)"
        }()
        report += "Entity Counts: \(eventCount) Events, \(teamCount) Teams, \(sightingCount) Sightings\n"

        report += "\nUserDefaults:\n"
        let knownKeys = AppPreferences.diagnosticsSafeKeys
        for key in knownKeys.sorted() {
            let value = UserDefaults.standard.object(forKey: key) ?? "<not set>"
            report += "  \(key) = \(value)\n"
        }

        let snapshot = lock.withLock { entries }
        report += "\n=== Session Log (newest first) ===\n"
        for entry in snapshot.reversed() {
            let dateStr = logDateFormatter.string(from: entry.date)
            let fileName = (entry.file as NSString).lastPathComponent
            report += "[\(dateStr)] [\(entry.level.rawValue.uppercased())] [\(entry.category)] \(entry.message) (\(fileName):\(entry.line))\n"
        }

        return report
    }

    @MainActor
    func exportURL(context: ModelContext) throws -> URL {
        let report = generateReport(context: context)
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent("SeenAt-Diagnostics-\(exportDateFormatter.string(from: Date())).txt")
        try report.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func reset() {
        lock.withLock {
            entries.removeAll()
        }
    }

    var entryCount: Int {
        lock.withLock { entries.count }
    }

    // MARK: - Private

    private let crashWatchKey = "com.seenat.diagnostics.crashWatch"

    private let logDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private let exportDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    private let byteCountFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()

}
