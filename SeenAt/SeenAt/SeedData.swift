#if DEBUG
import Foundation
import SwiftData

enum SeedData {
    @MainActor
    static func seedIfNeeded(in context: ModelContext) async -> Bool {
        guard let existingEvents = await fetchWithRetry(
            FetchDescriptor<Event>(),
            in: context,
            label: "events"
        ), existingEvents.isEmpty else {
            return false
        }

        guard let allTeams = await fetchWithRetry(
            FetchDescriptor<Team>(),
            in: context,
            label: "teams"
        ) else {
            return false
        }
        guard !Task.isCancelled else { return false }
        let requiredTeamNames = Set([
            "Chicago Cubs", "St. Louis Cardinals", "Los Angeles Lakers", "Chicago Bulls",
            "Green Bay Packers", "Chicago Bears", "Kansas City Chiefs", "New York Yankees",
            "Boston Red Sox", "Chicago Blackhawks", "Detroit Red Wings", "San Francisco Giants",
            "Los Angeles Dodgers"
        ])
        guard requiredTeamNames.isSubset(of: Set(allTeams.map(\.name))) else {
            DiagnosticsService.shared.log(category: "Seed", level: .error, message: "Required teams are unavailable; skipping seed data")
            return false
        }

        func team(_ name: String) -> Team? {
            allTeams.first { $0.name == name }
        }

        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        guard let yesterday = cal.date(byAdding: .day, value: -1, to: today),
              let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: today),
              let tomorrow = cal.date(byAdding: .day, value: 1, to: today) else {
            DiagnosticsService.shared.log(category: "Seed", level: .error, message: "Could not calculate seed dates")
            return false
        }

        func date(_ day: Date, hour: Int, minute: Int = 0) -> Date? {
            cal.date(bySettingHour: hour, minute: minute, second: 0, of: day)
        }

        guard let e1Date = date(today, hour: 13),
              let e2Date = date(today, hour: 19),
              let e3Date = date(yesterday, hour: 12),
              let e4Date = date(tomorrow, hour: 18),
              let e5Date = date(twoDaysAgo, hour: 19),
              let e6Date = date(yesterday, hour: 18) else {
            DiagnosticsService.shared.log(category: "Seed", level: .error, message: "Could not calculate seed event dates")
            return false
        }

        func assignID(_ string: String, to event: Event) -> Bool {
            guard let id = UUID(uuidString: string) else {
                DiagnosticsService.shared.log(category: "Seed", level: .error, message: "Invalid seed event ID: \(string)")
                return false
            }
            event.id = id
            return true
        }

        // Event 1 — Today, Cardinals @ Cubs at Wrigley Field (stadium)
        let e1 = Event(awayTeam: "St. Louis Cardinals", homeTeam: "Chicago Cubs", date: e1Date, venue: "Wrigley Field", watchLocation: .stadium)
        guard assignID("11111111-1111-1111-1111-111111111111", to: e1) else { return false }
        context.insert(e1)

        addSighting(context: context, team: team("Chicago Cubs"), firstName: "Rizzo", number: "44", event: e1)
        addSighting(context: context, team: team("Chicago Cubs"), firstName: "Báez", number: "9", event: e1)
        addSighting(context: context, team: team("St. Louis Cardinals"), number: "12", event: e1)
        addSighting(context: context, team: team("Chicago Cubs"), firstName: "Sandberg", number: "23", event: e1)
        addSighting(context: context, team: team("St. Louis Cardinals"), firstName: "Pujols", number: "5", event: e1)

        // Event 2 — Today, Lakers @ Bulls at United Center (tv)
        let e2 = Event(awayTeam: "Los Angeles Lakers", homeTeam: "Chicago Bulls", date: e2Date, venue: "United Center", watchLocation: .tv)
        guard assignID("22222222-2222-2222-2222-222222222222", to: e2) else { return false }
        context.insert(e2)

        addSighting(context: context, team: team("Chicago Bulls"), firstName: "Jordan", number: "23", event: e2)
        addSighting(context: context, team: team("Los Angeles Lakers"), firstName: "James", number: "23", event: e2)
        addSighting(context: context, team: team("Chicago Bulls"), firstName: "Pippen", number: "33", event: e2)
        addSighting(context: context, team: team("Los Angeles Lakers"), firstName: "Bryant", number: "24", event: e2)

        // Event 3 — Yesterday, Packers @ Bears at Soldier Field (stadium)
        let e3 = Event(awayTeam: "Green Bay Packers", homeTeam: "Chicago Bears", date: e3Date, venue: "Soldier Field", watchLocation: .stadium)
        guard assignID("33333333-3333-3333-3333-333333333333", to: e3) else { return false }
        context.insert(e3)

        addSighting(context: context, team: team("Green Bay Packers"), firstName: "Favre", number: "4", event: e3)
        addSighting(context: context, team: team("Chicago Bears"), firstName: "Urlacher", number: "54", event: e3)
        addSighting(context: context, team: team("Kansas City Chiefs"), firstName: "Mahomes", number: "15", event: e3)
        addSighting(context: context, team: team("Green Bay Packers"), number: "88", event: e3)
        addSighting(context: context, team: team("Chicago Bears"), firstName: "Payton", number: "34", event: e3)

        // Event 4 — Tomorrow, Yankees @ Red Sox at Fenway Park (stadium) — no sightings
        let e4 = Event(awayTeam: "New York Yankees", homeTeam: "Boston Red Sox", date: e4Date, venue: "Fenway Park", watchLocation: .stadium)
        guard assignID("44444444-4444-4444-4444-444444444444", to: e4) else { return false }
        context.insert(e4)

        // Event 5 — 2 days ago, Blackhawks @ Red Wings at Little Caesars Arena (tv)
        let e5 = Event(awayTeam: "Chicago Blackhawks", homeTeam: "Detroit Red Wings", date: e5Date, venue: "Little Caesars Arena", watchLocation: .tv)
        guard assignID("55555555-5555-5555-5555-555555555555", to: e5) else { return false }
        context.insert(e5)

        addSighting(context: context, team: team("Chicago Blackhawks"), firstName: "Kane", number: "88", event: e5)
        addSighting(context: context, team: team("Detroit Red Wings"), firstName: "Yzerman", number: "19", event: e5)
        addSighting(context: context, team: team("Chicago Blackhawks"), firstName: "Toews", number: "19", event: e5)
        addSighting(context: context, team: team("Chicago Blackhawks"), number: "50", event: e5)

        // Event 6 — Yesterday, Giants @ Dodgers at Dodger Stadium (stadium)
        let e6 = Event(awayTeam: "San Francisco Giants", homeTeam: "Los Angeles Dodgers", date: e6Date, venue: "Dodger Stadium", watchLocation: .stadium)
        guard assignID("66666666-6666-6666-6666-666666666666", to: e6) else { return false }
        context.insert(e6)

        addSighting(context: context, team: team("Los Angeles Dodgers"), firstName: "Ohtani", number: "17", event: e6)
        addSighting(context: context, team: team("San Francisco Giants"), firstName: "Posey", number: "28", event: e6)
        addSighting(context: context, team: team("Los Angeles Dodgers"), firstName: "Betts", number: "50", event: e6)
        addSighting(context: context, team: team("San Francisco Giants"), number: "9", event: e6)
        addSighting(context: context, team: team("Los Angeles Dodgers"), firstName: "Freeman", number: "5", event: e6)

        guard context.saveAndLog("Failed to save seed data") else {
            context.rollback()
            return false
        }
        return true
    }

    @MainActor
    private static func fetchWithRetry<Model: PersistentModel>(
        _ descriptor: FetchDescriptor<Model>,
        in context: ModelContext,
        label: String
    ) async -> [Model]? {
        for attempt in 0..<3 {
            guard !Task.isCancelled else { return nil }
            do {
                return try context.fetch(descriptor)
            } catch {
                guard attempt < 2 else {
                    DiagnosticsService.shared.log(
                        category: "Seed",
                        level: .error,
                        message: "Failed to fetch \(label): \(error.localizedDescription)"
                    )
                    return nil
                }
                do {
                    try await Task.sleep(nanoseconds: 100_000_000)
                } catch is CancellationError {
                    DiagnosticsService.shared.log(
                        category: "Seed",
                        level: .debug,
                        message: "Cancelled while retrying \(label) fetch"
                    )
                    return nil
                } catch {
                    DiagnosticsService.shared.log(
                        category: "Seed",
                        level: .error,
                        message: "Retry delay failed for \(label) fetch: \(error.localizedDescription)"
                    )
                    return nil
                }
            }
        }
        return nil
    }

    @MainActor
    private static func addSighting(context: ModelContext, team: Team?, firstName: String? = nil, number: String? = nil, event: Event) {
        let s = JerseySighting(team: team, firstName: firstName, lastName: nil, playerNumber: number, event: event)
        context.insert(s)
    }
}
#endif
