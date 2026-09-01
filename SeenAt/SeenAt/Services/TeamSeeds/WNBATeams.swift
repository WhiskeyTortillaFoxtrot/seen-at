import Foundation

enum WNBATeams {
    @MainActor static var all: [Team] { [
        Team(name: "Atlanta Dream", abbreviation: "ATL", sport: "wnba", isBuiltIn: true, primaryColorHex: "#C8102E", secondaryColorHex: "#000000"),
        Team(name: "Chicago Sky", abbreviation: "CHI", sport: "wnba", isBuiltIn: true, primaryColorHex: "#418FDE", secondaryColorHex: "#FFCD00"),
        Team(name: "Connecticut Sun", abbreviation: "CON", sport: "wnba", isBuiltIn: true, primaryColorHex: "#EF3B24", secondaryColorHex: "#000000"),
        Team(name: "Dallas Wings", abbreviation: "DAL", sport: "wnba", isBuiltIn: true, primaryColorHex: "#00A3E0", secondaryColorHex: "#B9975B"),
        Team(name: "Golden State Valkyries", abbreviation: "GSV", sport: "wnba", isBuiltIn: true, primaryColorHex: "#AD96DC", secondaryColorHex: "#010101"),
        Team(name: "Indiana Fever", abbreviation: "IND", sport: "wnba", isBuiltIn: true, primaryColorHex: "#002D62", secondaryColorHex: "#FDBB30"),
        Team(name: "Las Vegas Aces", abbreviation: "LVA", sport: "wnba", isBuiltIn: true, primaryColorHex: "#000000", secondaryColorHex: "#A71930"),
        Team(name: "Los Angeles Sparks", abbreviation: "LAS", sport: "wnba", isBuiltIn: true, primaryColorHex: "#702F8A", secondaryColorHex: "#F7C500"),
        Team(name: "Minnesota Lynx", abbreviation: "MIN", sport: "wnba", isBuiltIn: true, primaryColorHex: "#266092", secondaryColorHex: "#78BE20"),
        Team(name: "New York Liberty", abbreviation: "NYL", sport: "wnba", isBuiltIn: true, primaryColorHex: "#00A1DE", secondaryColorHex: "#000000"),
        Team(name: "Phoenix Mercury", abbreviation: "PHX", sport: "wnba", isBuiltIn: true, primaryColorHex: "#1D1160", secondaryColorHex: "#E56020"),
        Team(name: "Portland Fire", abbreviation: "POR", sport: "wnba", isBuiltIn: true, primaryColorHex: "#C8102E", secondaryColorHex: "#E93CAC"),
        Team(name: "Seattle Storm", abbreviation: "SEA", sport: "wnba", isBuiltIn: true, primaryColorHex: "#2C5234", secondaryColorHex: "#8BC53F"),
        Team(name: "Toronto Tempo", abbreviation: "TOR", sport: "wnba", isBuiltIn: true, primaryColorHex: "#612C51", secondaryColorHex: "#B8CCEA"),
        Team(name: "Washington Mystics", abbreviation: "WAS", sport: "wnba", isBuiltIn: true, primaryColorHex: "#0C2340", secondaryColorHex: "#E31837"),
    ]
    }
}
