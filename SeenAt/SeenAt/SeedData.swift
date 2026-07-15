#if DEBUG
import Foundation
import SwiftData

enum SeedData {
    @MainActor
    static func seedIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<Event>()
        let existing = try? context.fetch(descriptor)
        guard existing == nil || existing!.isEmpty else { return }

        let teamDesc = FetchDescriptor<Team>()
        let allTeams = (try? context.fetch(teamDesc)) ?? []

        func team(_ name: String) -> Team? {
            allTeams.first { $0.name == name }
        }

        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let twoDaysAgo = cal.date(byAdding: .day, value: -2, to: today)!
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today)!

        func date(_ day: Date, hour: Int, minute: Int = 0) -> Date {
            cal.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
        }

        // Event 1 — Today, Cardinals @ Cubs at Wrigley Field (stadium)
        let e1 = Event(awayTeam: "St. Louis Cardinals", homeTeam: "Chicago Cubs", date: date(today, hour: 13), venue: "Wrigley Field", watchLocation: .stadium)
        e1.id = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        context.insert(e1)

        addSighting(context: context, team: team("Chicago Cubs"), firstName: "Rizzo", number: "44", event: e1)
        addSighting(context: context, team: team("Chicago Cubs"), firstName: "Báez", number: "9", event: e1)
        addSighting(context: context, team: team("St. Louis Cardinals"), number: "12", event: e1)
        addSighting(context: context, team: team("Chicago Cubs"), firstName: "Sandberg", number: "23", event: e1)
        addSighting(context: context, team: team("St. Louis Cardinals"), firstName: "Pujols", number: "5", event: e1)

        // Event 2 — Today, Lakers @ Bulls at United Center (tv)
        let e2 = Event(awayTeam: "Los Angeles Lakers", homeTeam: "Chicago Bulls", date: date(today, hour: 19), venue: "United Center", watchLocation: .tv)
        e2.id = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        context.insert(e2)

        addSighting(context: context, team: team("Chicago Bulls"), firstName: "Jordan", number: "23", event: e2)
        addSighting(context: context, team: team("Los Angeles Lakers"), firstName: "James", number: "23", event: e2)
        addSighting(context: context, team: team("Chicago Bulls"), firstName: "Pippen", number: "33", event: e2)
        addSighting(context: context, team: team("Los Angeles Lakers"), firstName: "Bryant", number: "24", event: e2)

        // Event 3 — Yesterday, Packers @ Bears at Soldier Field (stadium)
        let e3 = Event(awayTeam: "Green Bay Packers", homeTeam: "Chicago Bears", date: date(yesterday, hour: 12), venue: "Soldier Field", watchLocation: .stadium)
        e3.id = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        context.insert(e3)

        addSighting(context: context, team: team("Green Bay Packers"), firstName: "Favre", number: "4", event: e3)
        addSighting(context: context, team: team("Chicago Bears"), firstName: "Urlacher", number: "54", event: e3)
        addSighting(context: context, team: team("Kansas City Chiefs"), firstName: "Mahomes", number: "15", event: e3)
        addSighting(context: context, team: team("Green Bay Packers"), number: "88", event: e3)
        addSighting(context: context, team: team("Chicago Bears"), firstName: "Payton", number: "34", event: e3)

        // Event 4 — Tomorrow, Yankees @ Red Sox at Fenway Park (stadium) — no sightings
        let e4 = Event(awayTeam: "New York Yankees", homeTeam: "Boston Red Sox", date: date(tomorrow, hour: 18), venue: "Fenway Park", watchLocation: .stadium)
        e4.id = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        context.insert(e4)

        // Event 5 — 2 days ago, Blackhawks @ Red Wings at Little Caesars Arena (tv)
        let e5 = Event(awayTeam: "Chicago Blackhawks", homeTeam: "Detroit Red Wings", date: date(twoDaysAgo, hour: 19), venue: "Little Caesars Arena", watchLocation: .tv)
        e5.id = UUID(uuidString: "55555555-5555-5555-5555-555555555555")!
        context.insert(e5)

        addSighting(context: context, team: team("Chicago Blackhawks"), firstName: "Kane", number: "88", event: e5)
        addSighting(context: context, team: team("Detroit Red Wings"), firstName: "Yzerman", number: "19", event: e5)
        addSighting(context: context, team: team("Chicago Blackhawks"), firstName: "Toews", number: "19", event: e5)
        addSighting(context: context, team: team("Chicago Blackhawks"), number: "50", event: e5)

        context.saveAndLog("Failed to save seed data")
    }

    @MainActor
    private static func addSighting(context: ModelContext, team: Team?, firstName: String? = nil, number: String? = nil, event: Event) {
        let s = JerseySighting(team: team, firstName: firstName, lastName: nil, playerNumber: number, event: event)
        context.insert(s)
    }
}
#endif
