@testable import SeenAt
import Foundation
import SwiftData

@MainActor
enum TestModelContainer {
    static func create() -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try! ModelContainer(
            for: Team.self, Event.self, JerseySighting.self,
            configurations: config
        )
    }

    static func createSQLite() -> ModelContainer {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).sqlite")
        let config = ModelConfiguration(url: url)
        return try! ModelContainer(
            for: Team.self, Event.self, JerseySighting.self,
            configurations: config
        )
    }

    static func cleanupSQLite(_ container: ModelContainer) {
        if let url = container.configurations.first?.url,
           url.absoluteString.contains("test_") {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
