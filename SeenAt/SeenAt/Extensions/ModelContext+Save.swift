import Foundation
import SwiftData
import OSLog

extension ModelContext {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.seenat",
        category: "ModelContext"
    )

    @discardableResult
    func saveAndLog(_ message: String = "Save failed") -> Bool {
        do {
            try save()
            return true
        } catch {
            Self.logger.error("\(message): \(error, privacy: .auto)")
            return false
        }
    }
}
