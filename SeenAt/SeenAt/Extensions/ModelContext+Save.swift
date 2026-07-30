import Foundation
import SwiftData

extension ModelContext {
    @discardableResult
    func saveAndLog(_ message: String = "Save failed") -> Bool {
        do {
            try save()
            return true
        } catch {
            DiagnosticsService.shared.log(category: "ModelContext", level: .error, message: "\(message): \(error.localizedDescription)")
            return false
        }
    }
}
