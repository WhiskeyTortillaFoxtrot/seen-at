import Foundation

enum NBATeams {
    @MainActor static var all: [Team] { [
        Team(name: "Atlanta Hawks", abbreviation: "ATL", sport: "nba", isBuiltIn: true, primaryColorHex: "#E03A3E", secondaryColorHex: "#C1D32F"),
        Team(name: "Boston Celtics", abbreviation: "BOS", sport: "nba", isBuiltIn: true, primaryColorHex: "#007A33", secondaryColorHex: "#BA9653"),
        Team(name: "Brooklyn Nets", abbreviation: "BKN", sport: "nba", isBuiltIn: true, primaryColorHex: "#000000", secondaryColorHex: "#FFFFFF"),
        Team(name: "Charlotte Hornets", abbreviation: "CHA", sport: "nba", isBuiltIn: true, primaryColorHex: "#1D1160", secondaryColorHex: "#00788C"),
        Team(name: "Chicago Bulls", abbreviation: "CHI", sport: "nba", isBuiltIn: true, primaryColorHex: "#CE1141", secondaryColorHex: "#000000"),
        Team(name: "Cleveland Cavaliers", abbreviation: "CLE", sport: "nba", isBuiltIn: true, primaryColorHex: "#860038", secondaryColorHex: "#FDBB30"),
        Team(name: "Dallas Mavericks", abbreviation: "DAL", sport: "nba", isBuiltIn: true, primaryColorHex: "#00538C", secondaryColorHex: "#002B5E"),
        Team(name: "Denver Nuggets", abbreviation: "DEN", sport: "nba", isBuiltIn: true, primaryColorHex: "#0E2240", secondaryColorHex: "#FEC524"),
        Team(name: "Detroit Pistons", abbreviation: "DET", sport: "nba", isBuiltIn: true, primaryColorHex: "#C8102E", secondaryColorHex: "#1D428A"),
        Team(name: "Golden State Warriors", abbreviation: "GSW", sport: "nba", isBuiltIn: true, primaryColorHex: "#1D428A", secondaryColorHex: "#FFC72C"),
        Team(name: "Houston Rockets", abbreviation: "HOU", sport: "nba", isBuiltIn: true, primaryColorHex: "#CE1141", secondaryColorHex: "#000000"),
        Team(name: "Indiana Pacers", abbreviation: "IND", sport: "nba", isBuiltIn: true, primaryColorHex: "#002D62", secondaryColorHex: "#FDBB30"),
        Team(name: "Los Angeles Clippers", abbreviation: "LAC", sport: "nba", isBuiltIn: true, primaryColorHex: "#C8102E", secondaryColorHex: "#1D428A"),
        Team(name: "Los Angeles Lakers", abbreviation: "LAL", sport: "nba", isBuiltIn: true, primaryColorHex: "#552583", secondaryColorHex: "#FDB927"),
        Team(name: "Memphis Grizzlies", abbreviation: "MEM", sport: "nba", isBuiltIn: true, primaryColorHex: "#5D76A9", secondaryColorHex: "#12173F"),
        Team(name: "Miami Heat", abbreviation: "MIA", sport: "nba", isBuiltIn: true, primaryColorHex: "#98002E", secondaryColorHex: "#F9A01B"),
        Team(name: "Milwaukee Bucks", abbreviation: "MIL", sport: "nba", isBuiltIn: true, primaryColorHex: "#00471B", secondaryColorHex: "#EEE1C6"),
        Team(name: "Minnesota Timberwolves", abbreviation: "MIN", sport: "nba", isBuiltIn: true, primaryColorHex: "#0C2340", secondaryColorHex: "#78BE20"),
        Team(name: "New Orleans Pelicans", abbreviation: "NOP", sport: "nba", isBuiltIn: true, primaryColorHex: "#0C2340", secondaryColorHex: "#C8102E"),
        Team(name: "New York Knicks", abbreviation: "NYK", sport: "nba", isBuiltIn: true, primaryColorHex: "#006BB6", secondaryColorHex: "#F58426"),
        Team(name: "Oklahoma City Thunder", abbreviation: "OKC", sport: "nba", isBuiltIn: true, primaryColorHex: "#007AC1", secondaryColorHex: "#EF3B24"),
        Team(name: "Orlando Magic", abbreviation: "ORL", sport: "nba", isBuiltIn: true, primaryColorHex: "#0077C0", secondaryColorHex: "#000000"),
        Team(name: "Philadelphia 76ers", abbreviation: "PHI", sport: "nba", isBuiltIn: true, primaryColorHex: "#006BB6", secondaryColorHex: "#ED174C"),
        Team(name: "Phoenix Suns", abbreviation: "PHX", sport: "nba", isBuiltIn: true, primaryColorHex: "#1D1160", secondaryColorHex: "#E56020"),
        Team(name: "Portland Trail Blazers", abbreviation: "POR", sport: "nba", isBuiltIn: true, primaryColorHex: "#E03A3E", secondaryColorHex: "#000000"),
        Team(name: "Sacramento Kings", abbreviation: "SAC", sport: "nba", isBuiltIn: true, primaryColorHex: "#5A2D82", secondaryColorHex: "#63727A"),
        Team(name: "San Antonio Spurs", abbreviation: "SAS", sport: "nba", isBuiltIn: true, primaryColorHex: "#C4CED4", secondaryColorHex: "#000000"),
        Team(name: "Toronto Raptors", abbreviation: "TOR", sport: "nba", isBuiltIn: true, primaryColorHex: "#CE1141", secondaryColorHex: "#000000"),
        Team(name: "Utah Jazz", abbreviation: "UTA", sport: "nba", isBuiltIn: true, primaryColorHex: "#002B5C", secondaryColorHex: "#F9A01B"),
        Team(name: "Washington Wizards", abbreviation: "WAS", sport: "nba", isBuiltIn: true, primaryColorHex: "#002B5C", secondaryColorHex: "#E31837"),
    ]
    }
}
