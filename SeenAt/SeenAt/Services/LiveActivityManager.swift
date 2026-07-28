import Foundation
@preconcurrency import ActivityKit

@MainActor
protocol LiveActivityClient {
    var activeEventIDs: [UUID] { get }

    func request(
        attributes: SeenAtActivityAttributes,
        contentState: SeenAtActivityAttributes.ContentState
    ) async
    func update(eventID: UUID, contentState: SeenAtActivityAttributes.ContentState) async
    func end(eventID: UUID) async
    func endAll() async
}

@MainActor
struct ActivityKitLiveActivityClient: LiveActivityClient {
    var activeEventIDs: [UUID] {
        Activity<SeenAtActivityAttributes>.activities.map { $0.attributes.eventID }
    }

    func request(
        attributes: SeenAtActivityAttributes,
        contentState: SeenAtActivityAttributes.ContentState
    ) async {
        try? await Activity<SeenAtActivityAttributes>.request(
            attributes: attributes,
            content: .init(state: contentState, staleDate: nil)
        )
    }

    func update(eventID: UUID, contentState: SeenAtActivityAttributes.ContentState) async {
        for activity in Activity<SeenAtActivityAttributes>.activities
            where activity.attributes.eventID == eventID {
            await activity.update(using: contentState)
        }
    }

    func end(eventID: UUID) async {
        for activity in Activity<SeenAtActivityAttributes>.activities
            where activity.attributes.eventID == eventID {
            await activity.end(dismissalPolicy: .immediate)
        }
    }

    func endAll() async {
        for activity in Activity<SeenAtActivityAttributes>.activities {
            await activity.end(dismissalPolicy: .immediate)
        }
    }
}

@MainActor
enum LiveActivityManager {
    private static var pendingStartEventIDs = Set<UUID>()

    static func findBestTodayEvent(in events: [Event]) -> Event? {
        let todayEvents = events.filter { Calendar.current.isDateInToday($0.date) }
        guard !todayEvents.isEmpty else { return nil }
        return todayEvents.max { a, b in
            let aLatest = a.sightings.max(by: { $0.timestamp < $1.timestamp })?.timestamp ?? a.createdAt
            let bLatest = b.sightings.max(by: { $0.timestamp < $1.timestamp })?.timestamp ?? b.createdAt
            return aLatest < bLatest
        }
    }

    static func startOrUpdate(
        for event: Event,
        teams: [Team],
        client: any LiveActivityClient = ActivityKitLiveActivityClient()
    ) async {
        let awayTeamName = event.awayTeam ?? ""
        let homeTeamName = event.homeTeam ?? ""

        let homeTeam = teams.first { $0.name == homeTeamName }
        let awayTeam = teams.first { $0.name == awayTeamName }

        let homeColor = homeTeam?.primaryColorHex ?? "000000"
        let awayColor = awayTeam?.secondaryColorHex ?? "000000"

        let contentState = SeenAtActivityAttributes.ContentState(
            jerseyCount: event.totalCount,
            mostRecentJerseyName: event.sightings
                .sorted { $0.timestamp > $1.timestamp }
                .first(where: { $0.isPlayerSighting })?.displayName ?? ""
        )

        let attributes = SeenAtActivityAttributes(
            eventID: event.id,
            gameTitle: event.title,
            homeTeamColor: homeColor,
            awayTeamColor: awayColor
        )

        if client.activeEventIDs.contains(event.id) {
            await client.update(eventID: event.id, contentState: contentState)
        } else {
            guard pendingStartEventIDs.insert(event.id).inserted else { return }
            defer { pendingStartEventIDs.remove(event.id) }

            await client.request(
                attributes: attributes,
                contentState: contentState
            )
        }
    }

    static func end(
        for eventID: UUID,
        client: any LiveActivityClient = ActivityKitLiveActivityClient()
    ) async {
        await client.end(eventID: eventID)
    }

    static func end(
        for event: Event,
        client: any LiveActivityClient = ActivityKitLiveActivityClient()
    ) async {
        await end(for: event.id, client: client)
    }

    static func endAll(client: any LiveActivityClient = ActivityKitLiveActivityClient()) async {
        await client.endAll()
    }

    static func endStaleActivities(
        for events: [Event],
        client: any LiveActivityClient = ActivityKitLiveActivityClient()
    ) async {
        let activeIDs = Set(events.filter { Calendar.current.isDateInToday($0.date) }.map(\.id))
        for eventID in client.activeEventIDs {
            if !activeIDs.contains(eventID) {
                await client.end(eventID: eventID)
            }
        }
    }
}
