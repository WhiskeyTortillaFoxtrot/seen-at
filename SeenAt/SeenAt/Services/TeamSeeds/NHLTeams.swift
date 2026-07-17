import Foundation

enum NHLTeams {
    @MainActor static var all: [Team] { [
        Team(name: "Anaheim Ducks", abbreviation: "ANA", sport: "nhl", isBuiltIn: true, primaryColorHex: "#F47A38", secondaryColorHex: "#111111"),
        Team(name: "Boston Bruins", abbreviation: "BOS", sport: "nhl", isBuiltIn: true, primaryColorHex: "#FFB81C", secondaryColorHex: "#111111"),
        Team(name: "Buffalo Sabres", abbreviation: "BUF", sport: "nhl", isBuiltIn: true, primaryColorHex: "#003087", secondaryColorHex: "#FFB81C"),
        Team(name: "Calgary Flames", abbreviation: "CGY", sport: "nhl", isBuiltIn: true, primaryColorHex: "#C8102E", secondaryColorHex: "#F1BE48"),
        Team(name: "Carolina Hurricanes", abbreviation: "CAR", sport: "nhl", isBuiltIn: true, primaryColorHex: "#CC0000", secondaryColorHex: "#111111"),
        Team(name: "Chicago Blackhawks", abbreviation: "CHI", sport: "nhl", isBuiltIn: true, primaryColorHex: "#CF0A2C", secondaryColorHex: "#111111"),
        Team(name: "Colorado Avalanche", abbreviation: "COL", sport: "nhl", isBuiltIn: true, primaryColorHex: "#6F263D", secondaryColorHex: "#236192"),
        Team(name: "Columbus Blue Jackets", abbreviation: "CBJ", sport: "nhl", isBuiltIn: true, primaryColorHex: "#002654", secondaryColorHex: "#CE1126"),
        Team(name: "Dallas Stars", abbreviation: "DAL", sport: "nhl", isBuiltIn: true, primaryColorHex: "#006847", secondaryColorHex: "#111111"),
        Team(name: "Detroit Red Wings", abbreviation: "DET", sport: "nhl", isBuiltIn: true, primaryColorHex: "#CE1126", secondaryColorHex: "#FFFFFF"),
        Team(name: "Edmonton Oilers", abbreviation: "EDM", sport: "nhl", isBuiltIn: true, primaryColorHex: "#041E42", secondaryColorHex: "#FF4C00"),
        Team(name: "Florida Panthers", abbreviation: "FLA", sport: "nhl", isBuiltIn: true, primaryColorHex: "#041E42", secondaryColorHex: "#C8102E"),
        Team(name: "Los Angeles Kings", abbreviation: "LAK", sport: "nhl", isBuiltIn: true, primaryColorHex: "#111111", secondaryColorHex: "#A2AAAD"),
        Team(name: "Minnesota Wild", abbreviation: "MIN", sport: "nhl", isBuiltIn: true, primaryColorHex: "#154734", secondaryColorHex: "#A6192E"),
        Team(name: "Montreal Canadiens", abbreviation: "MTL", sport: "nhl", isBuiltIn: true, primaryColorHex: "#AF1E2D", secondaryColorHex: "#192168"),
        Team(name: "Nashville Predators", abbreviation: "NSH", sport: "nhl", isBuiltIn: true, primaryColorHex: "#FFB81C", secondaryColorHex: "#041E42"),
        Team(name: "New Jersey Devils", abbreviation: "NJD", sport: "nhl", isBuiltIn: true, primaryColorHex: "#CE1126", secondaryColorHex: "#111111"),
        Team(name: "New York Islanders", abbreviation: "NYI", sport: "nhl", isBuiltIn: true, primaryColorHex: "#00539B", secondaryColorHex: "#F47A38"),
        Team(name: "New York Rangers", abbreviation: "NYR", sport: "nhl", isBuiltIn: true, primaryColorHex: "#0038A8", secondaryColorHex: "#CE1126"),
        Team(name: "Ottawa Senators", abbreviation: "OTT", sport: "nhl", isBuiltIn: true, primaryColorHex: "#C52032", secondaryColorHex: "#C6912E"),
        Team(name: "Philadelphia Flyers", abbreviation: "PHI", sport: "nhl", isBuiltIn: true, primaryColorHex: "#F74902", secondaryColorHex: "#111111"),
        Team(name: "Pittsburgh Penguins", abbreviation: "PIT", sport: "nhl", isBuiltIn: true, primaryColorHex: "#111111", secondaryColorHex: "#FCB514"),
        Team(name: "San Jose Sharks", abbreviation: "SJS", sport: "nhl", isBuiltIn: true, primaryColorHex: "#006D75", secondaryColorHex: "#EA7200"),
        Team(name: "Seattle Kraken", abbreviation: "SEA", sport: "nhl", isBuiltIn: true, primaryColorHex: "#001628", secondaryColorHex: "#99D9D9"),
        Team(name: "St. Louis Blues", abbreviation: "STL", sport: "nhl", isBuiltIn: true, primaryColorHex: "#002F87", secondaryColorHex: "#FCB514"),
        Team(name: "Tampa Bay Lightning", abbreviation: "TBL", sport: "nhl", isBuiltIn: true, primaryColorHex: "#002868", secondaryColorHex: "#FFFFFF"),
        Team(name: "Toronto Maple Leafs", abbreviation: "TOR", sport: "nhl", isBuiltIn: true, primaryColorHex: "#00205B", secondaryColorHex: "#FFFFFF"),
        Team(name: "Utah Mammoth", abbreviation: "UTA", sport: "nhl", isBuiltIn: true, primaryColorHex: "#71AFE5", secondaryColorHex: "#111111"),
        Team(name: "Vancouver Canucks", abbreviation: "VAN", sport: "nhl", isBuiltIn: true, primaryColorHex: "#00205B", secondaryColorHex: "#00843D"),
        Team(name: "Vegas Golden Knights", abbreviation: "VGK", sport: "nhl", isBuiltIn: true, primaryColorHex: "#B9975B", secondaryColorHex: "#333F42"),
        Team(name: "Washington Capitals", abbreviation: "WSH", sport: "nhl", isBuiltIn: true, primaryColorHex: "#041E42", secondaryColorHex: "#C8102E"),
        Team(name: "Winnipeg Jets", abbreviation: "WPG", sport: "nhl", isBuiltIn: true, primaryColorHex: "#041E42", secondaryColorHex: "#AC162C"),
    ]
    }
}
