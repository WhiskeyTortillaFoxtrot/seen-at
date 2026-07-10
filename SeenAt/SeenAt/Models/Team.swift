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
