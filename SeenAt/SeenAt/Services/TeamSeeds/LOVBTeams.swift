import Foundation

enum LOVBTeams {
    @MainActor static let all: [Team] = [
        Team(name: "LOVB Atlanta", abbreviation: "ATL", sport: "lovb", isBuiltIn: true, primaryColorHex: "#888888", secondaryColorHex: "#666666"),
        Team(name: "LOVB Austin", abbreviation: "ATX", sport: "lovb", isBuiltIn: true, primaryColorHex: "#888888", secondaryColorHex: "#666666"),
        Team(name: "LOVB Houston", abbreviation: "HTX", sport: "lovb", isBuiltIn: true, primaryColorHex: "#888888", secondaryColorHex: "#666666"),
        Team(name: "LOVB Madison", abbreviation: "MAD", sport: "lovb", isBuiltIn: true, primaryColorHex: "#888888", secondaryColorHex: "#666666"),
        Team(name: "LOVB Nebraska", abbreviation: "NEB", sport: "lovb", isBuiltIn: true, primaryColorHex: "#888888", secondaryColorHex: "#666666"),
        Team(name: "LOVB Salt Lake", abbreviation: "SLC", sport: "lovb", isBuiltIn: true, primaryColorHex: "#888888", secondaryColorHex: "#666666"),
    ]
    // TODO: Replace #888888 with official LOVB team colors
}
