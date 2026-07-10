import Foundation
@preconcurrency import ActivityKit

@MainActor
enum LiveActivityManager {

    static func findBestTodayEvent(in events: [Event]) -> Event? {
        let todayEvents = events.filter { Calendar.current.isDateInToday($0.date) }
        guard !todayEvents.isEmpty else { return nil }
        return todayEvents.max { a, b in
            let aLatest = a.sightings.max(by: { $0.timestamp < $1.timestamp })?.timestamp ?? a.createdAt
            let bLatest = b.sightings.max(by: { $0.timestamp < $1.timestamp })?.timestamp ?? b.createdAt
            return aLatest < bLatest
        }
    }

    static func startOrUpdate(for event: Event, teams: [Team]) async {
        let parts = event.title.components(separatedBy: " @ ")
        let awayTeamName = parts.count == 2 ? parts[0].trimmingCharacters(in: .whitespaces) : ""
        let homeTeamName = parts.count == 2 ? parts[1].trimmingCharacters(in: .whitespaces) : ""

        let homeTeam = teams.first { $0.name == homeTeamName }
        let awayTeam = teams.first { $0.name == awayTeamName }

        let homeColor = homeTeam?.primaryColorHex ?? "000000"
        let awayColor = awayTeam?.secondaryColorHex ?? "000000"

        let contentState = SeenAtActivityAttributes.ContentState(
            jerseyCount: event.totalCount,
            mostRecentJerseyName: event.sightings
                .sorted { $0.timestamp > $1.timestamp }
                .first?.displayName ?? ""
        )

        let attributes = SeenAtActivityAttributes(
            eventID: event.id,
            gameTitle: event.title,
            homeTeamColor: homeColor,
            awayTeamColor: awayColor
        )

        if let existing = Activity<SeenAtActivityAttributes>.activities.first(where: { $0.attributes.eventID == event.id }) {
            await existing.update(using: contentState)
        } else {
            try? await Activity<SeenAtActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil)
            )
        }
    }

    static func end(for event: Event) async {
        let activities = Activity<SeenAtActivityAttributes>.activities.filter { $0.attributes.eventID == event.id }
        for activity in activities {
            await activity.end(dismissalPolicy: .immediate)
        }
    }

    static func endAll() async {
        for activity in Activity<SeenAtActivityAttributes>.activities {
            await activity.end(dismissalPolicy: .immediate)
        }
    }

    static func endStaleActivities(for events: [Event]) async {
        let activeIDs = Set(events.filter { Calendar.current.isDateInToday($0.date) }.map(\.id))
        for activity in Activity<SeenAtActivityAttributes>.activities {
            if !activeIDs.contains(activity.attributes.eventID) {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
    }
}
