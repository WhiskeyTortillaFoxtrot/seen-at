import Foundation
import ActivityKit

struct SeenAtActivityAttributes: ActivityAttributes, Sendable {
    let eventID: UUID
    let gameTitle: String
    let homeTeamColor: String
    let awayTeamColor: String

    struct ContentState: Codable & Hashable & Sendable {
        let jerseyCount: Int
        let mostRecentJerseyName: String
    }
}
