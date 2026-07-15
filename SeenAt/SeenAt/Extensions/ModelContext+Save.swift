import Foundation
import SwiftData
import OSLog

extension ModelContext {
    @discardableResult
    func saveAndLog(_ message: String = "Save failed") -> Bool {
        do {
            try save()
            return true
        } catch {
            Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.seenat", category: "ModelContext")
                .error("\(message): \(error, privacy: .public)")
            return false
        }
    }
}
