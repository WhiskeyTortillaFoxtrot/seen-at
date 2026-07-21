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
            let base = url.deletingPathExtension()
            let sidecars = [
                url,
                base.appendingPathExtension("\(url.pathExtension)-wal"),
                base.appendingPathExtension("\(url.pathExtension)-shm"),
                url.deletingLastPathComponent()
                    .appendingPathComponent(".\(base.lastPathComponent)_SUPPORT", isDirectory: true),
            ]
            for artifact in sidecars {
                try? FileManager.default.removeItem(at: artifact)
            }
        }
    }
}
