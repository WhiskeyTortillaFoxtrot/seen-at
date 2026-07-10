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
}
