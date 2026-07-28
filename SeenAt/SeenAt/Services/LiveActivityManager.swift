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
    private struct RetiredStart {
        let token: UUID
        let task: Task<Void, Never>
    }

    private static var pendingStartTasks: [UUID: Task<Void, Never>] = [:]
    private static var pendingStartTokens: [UUID: UUID] = [:]
    private static var pendingLatestStates: [UUID: SeenAtActivityAttributes.ContentState] = [:]
    private static var retiredStarts: [UUID: RetiredStart] = [:]
    private static var pendingUpdateTasks: [UUID: Task<Void, Never>] = [:]
    private static var pendingUpdateStates: [UUID: SeenAtActivityAttributes.ContentState] = [:]
    private static var lifecycleGenerations: [UUID: Int] = [:]
    private static var globalLifecycleGeneration = 0
    private static var endingTasks: [UUID: Task<Void, Never>] = [:]
    private static var endingAllTask: Task<Void, Never>?

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
        let generation = lifecycleGenerations[event.id, default: 0]
        let globalGeneration = globalLifecycleGeneration
        await startOrUpdate(
            for: event,
            teams: teams,
            client: client,
            generation: generation,
            globalGeneration: globalGeneration
        )
    }

    private static func startOrUpdate(
        for event: Event,
        teams: [Team],
        client: any LiveActivityClient,
        generation: Int,
        globalGeneration: Int
    ) async {
        if let endingAllTask {
            await endingAllTask.value
            guard globalLifecycleGeneration == globalGeneration else { return }
            return await startOrUpdate(
                for: event,
                teams: teams,
                client: client,
                generation: lifecycleGenerations[event.id, default: 0],
                globalGeneration: globalLifecycleGeneration
            )
        }

        if let endingTask = endingTasks[event.id] {
            await endingTask.value
            guard lifecycleGenerations[event.id, default: 0] == generation,
                  globalLifecycleGeneration == globalGeneration else { return }
            return await startOrUpdate(
                for: event,
                teams: teams,
                client: client,
                generation: generation,
                globalGeneration: globalGeneration
            )
        }

        if let retiredStart = retiredStarts[event.id] {
            await retiredStart.task.value
            guard lifecycleGenerations[event.id, default: 0] == generation,
                  globalLifecycleGeneration == globalGeneration else { return }
            return await startOrUpdate(
                for: event,
                teams: teams,
                client: client,
                generation: generation,
                globalGeneration: globalGeneration
            )
        }

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

        let hasActiveActivity = client.activeEventIDs.contains(event.id)
        if let pendingStart = pendingStartTasks[event.id] {
            pendingLatestStates[event.id] = contentState
            await pendingStart.value
            return
        }

        if hasActiveActivity {
            if let pendingUpdate = pendingUpdateTasks[event.id] {
                pendingUpdateStates[event.id] = contentState
                await pendingUpdate.value
                return
            }

            let updateTask = Task { @MainActor in
                var appliedState: SeenAtActivityAttributes.ContentState?
                while lifecycleGenerations[event.id, default: 0] == generation,
                      globalLifecycleGeneration == globalGeneration {
                    let latestState = pendingUpdateStates[event.id] ?? contentState
                    if latestState == appliedState { break }
                    await client.update(eventID: event.id, contentState: latestState)
                    appliedState = latestState
                }
                if lifecycleGenerations[event.id, default: 0] == generation,
                   globalLifecycleGeneration == globalGeneration {
                    pendingUpdateTasks.removeValue(forKey: event.id)
                    pendingUpdateStates.removeValue(forKey: event.id)
                }
            }
            pendingUpdateTasks[event.id] = updateTask
            await updateTask.value
            return
        }

        let token = UUID()
        pendingStartTokens[event.id] = token
        pendingLatestStates[event.id] = contentState
        let requestTask = Task { @MainActor in
            await client.request(
                attributes: attributes,
                contentState: contentState
            )

            guard pendingStartTokens[event.id] == token else {
                if let retiredStart = retiredStarts[event.id], retiredStart.token == token {
                    await client.end(eventID: event.id)
                    retiredStarts.removeValue(forKey: event.id)
                }
                return
            }

            var appliedState = contentState
            while pendingStartTokens[event.id] == token {
                let latestState = pendingLatestStates[event.id] ?? appliedState
                guard latestState != appliedState else { break }
                await client.update(eventID: event.id, contentState: latestState)
                appliedState = latestState
            }

            if pendingStartTokens[event.id] == token {
                pendingStartTasks.removeValue(forKey: event.id)
                pendingStartTokens.removeValue(forKey: event.id)
                pendingLatestStates.removeValue(forKey: event.id)
            } else if let retiredStart = retiredStarts[event.id], retiredStart.token == token {
                await client.end(eventID: event.id)
                retiredStarts.removeValue(forKey: event.id)
            }
        }
        pendingStartTasks[event.id] = requestTask
        await requestTask.value
    }

    static func end(
        for eventID: UUID,
        client: any LiveActivityClient = ActivityKitLiveActivityClient()
    ) async {
        if let endingTask = endingTasks[eventID] {
            await endingTask.value
            return
        }

        let pendingUpdate = invalidatePendingStart(for: eventID)
        let endingTask = Task { @MainActor in
            await client.end(eventID: eventID)
            if let pendingUpdate {
                await pendingUpdate.value
                // A cancelled in-flight update may have re-requested or left the
                // activity alive. Call end again to ensure it is dismissed.
                await client.end(eventID: eventID)
            }
        }
        endingTasks[eventID] = endingTask
        await endingTask.value
        endingTasks.removeValue(forKey: eventID)
    }

    static func end(
        for event: Event,
        client: any LiveActivityClient = ActivityKitLiveActivityClient()
    ) async {
        await end(for: event.id, client: client)
    }

    static func endAll(client: any LiveActivityClient = ActivityKitLiveActivityClient()) async {
        if let endingAllTask {
            await endingAllTask.value
            return
        }

        let activeIDs = Set(client.activeEventIDs)
        let pendingIDs = activeIDs
            .union(pendingStartTasks.keys)
            .union(pendingUpdateTasks.keys)
        let pendingUpdates = pendingIDs.compactMap { pendingUpdateTasks[$0] }
        for eventID in pendingIDs {
            invalidatePendingStart(for: eventID)
        }
        for eventID in retiredStarts.keys {
            invalidatePendingStart(for: eventID)
        }
        globalLifecycleGeneration += 1
        let endingTask = Task { @MainActor in
            await client.endAll()
            for pendingUpdate in pendingUpdates {
                await pendingUpdate.value
            }
            if !pendingUpdates.isEmpty {
                await client.endAll()
            }
        }
        endingAllTask = endingTask
        await endingTask.value
        endingAllTask = nil
    }

    static func endStaleActivities(
        for events: [Event],
        client: any LiveActivityClient = ActivityKitLiveActivityClient()
    ) async {
        let activeIDs = Set(events.filter { Calendar.current.isDateInToday($0.date) }.map(\.id))
        let pendingIDs = Set(pendingStartTasks.keys)
            .union(retiredStarts.keys)
            .union(pendingUpdateTasks.keys)
        for eventID in pendingIDs
            where !activeIDs.contains(eventID) {
            await end(for: eventID, client: client)
        }
        for eventID in client.activeEventIDs {
            if !activeIDs.contains(eventID) {
                await end(for: eventID, client: client)
            }
        }
    }

    @discardableResult
    private static func invalidatePendingStart(for eventID: UUID) -> Task<Void, Never>? {
        lifecycleGenerations[eventID, default: 0] += 1
        let pendingUpdate = pendingUpdateTasks.removeValue(forKey: eventID)
        pendingUpdate?.cancel()
        pendingUpdateStates.removeValue(forKey: eventID)
        if let task = pendingStartTasks.removeValue(forKey: eventID),
           let token = pendingStartTokens[eventID] {
            retiredStarts[eventID] = RetiredStart(token: token, task: task)
            task.cancel()
        }
        pendingStartTokens.removeValue(forKey: eventID)
        pendingLatestStates.removeValue(forKey: eventID)
        return pendingUpdate
    }
}
