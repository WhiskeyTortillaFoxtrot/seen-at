import Foundation
@testable import SeenAt
@testable import SeenAt

enum TestDataFactory {
    static func makeTeam(
        name: String = "Test Team",
        abbreviation: String = "TT",
        sport: String = "mlb",
        primaryHex: String = "#A71930",
        secondaryHex: String = "#041E42"
    ) -> Team {
        Team(
            name: name,
            abbreviation: abbreviation,
            sport: sport,
            isBuiltIn: false,
            primaryColorHex: primaryHex,
            secondaryColorHex: secondaryHex
        )
    }

    static func makeEvent(
        title: String = "Home @ Away",
        date: Date = Date(),
        venue: String? = "Test Stadium"
    ) -> Event {
        Event(
            title: title,
            date: date,
            venue: venue
        )
    }

    static func makeSighting(
        team: Team? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        number: String? = nil,
        event: Event? = nil
    ) -> JerseySighting {
        JerseySighting(
            team: team,
            firstName: firstName,
            lastName: lastName,
            playerNumber: number,
            event: event
        )
    }
}
