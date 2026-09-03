import Foundation
import SwiftData

/// Resolves the two `Team` entities for an `Event`'s stored team-name strings.
/// Extracted from `LiveTrackingView`/`EventSummaryView` so the fetch is performed
/// once per event and tested in isolation instead of on every `body` evaluation.
enum TeamResolver {
    @MainActor
    static func teams(for event: Event, context: ModelContext) -> [Team] {
        teams(for: [event.homeTeam, event.awayTeam].compactMap { $0 }, context: context)
    }

    @MainActor
    static func teams(for names: [String], context: ModelContext) -> [Team] {
        guard !names.isEmpty else { return [] }
        let descriptor = FetchDescriptor<Team>(
            predicate: #Predicate<Team> { names.contains($0.name) }
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}
