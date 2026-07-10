import Foundation
import SwiftData
import SwiftUI

@Model
final class Team {
    @Attribute(.unique) var name: String
    var abbreviation: String
    var sport: String
    var isBuiltIn: Bool
    var primaryColorHex: String
    var secondaryColorHex: String
    var logoData: Data?

    @Relationship(deleteRule: .cascade)
    var sightings: [JerseySighting] = []

    var primaryColor: Color {
        Color(hex: primaryColorHex) ?? .gray
    }

    var secondaryColor: Color {
        Color(hex: secondaryColorHex) ?? .gray
    }

    var sportIcon: String {
        Team.sportIcon(for: sport)
    }

    static func sportIcon(for sport: String) -> String {
        switch sport.lowercased() {
        case "mlb": "baseball.fill"
        case "nba": "basketball.fill"
        case "nfl": "football.fill"
        case "nhl": "hockey.puck.fill"
        case "lovb": "volleyball.fill"
        default: "questionmark.circle.fill"
        }
    }

    init(
        name: String,
        abbreviation: String,
        sport: String = "mlb",
        isBuiltIn: Bool = false,
        primaryColorHex: String,
        secondaryColorHex: String,
        logoData: Data? = nil
    ) {
        self.name = name
        self.abbreviation = abbreviation
        self.sport = sport
        self.isBuiltIn = isBuiltIn
        self.primaryColorHex = primaryColorHex
        self.secondaryColorHex = secondaryColorHex
        self.logoData = logoData
    }
}
