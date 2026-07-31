import Foundation

enum NWSLTeams {
    @MainActor static var all: [Team] { [
        Team(name: "Angel City FC", abbreviation: "ACFC", sport: "nwsl", isBuiltIn: true, primaryColorHex: "#202121", secondaryColorHex: "#898C8F"),
        Team(name: "Bay FC", abbreviation: "BAY", sport: "nwsl", isBuiltIn: true, primaryColorHex: "#FF5049", secondaryColorHex: "#0D2032"),
        Team(name: "Boston Legacy FC", abbreviation: "BOS", sport: "nwsl", isBuiltIn: true, primaryColorHex: "#00A859", secondaryColorHex: "#000000"),
        Team(name: "Chicago Stars FC", abbreviation: "CHI", sport: "nwsl", isBuiltIn: true, primaryColorHex: "#C7102E", secondaryColorHex: "#3AB5E8"),
        Team(name: "Denver Summit FC", abbreviation: "DEN", sport: "nwsl", isBuiltIn: true, primaryColorHex: "#20604E", secondaryColorHex: "#E4B83E"),
        Team(name: "Gotham FC", abbreviation: "GFC", sport: "nwsl", isBuiltIn: true, primaryColorHex: "#0033A0", secondaryColorHex: "#ED1C24"),
        Team(name: "Houston Dash", abbreviation: "HOU", sport: "nwsl", isBuiltIn: true, primaryColorHex: "#FF6900", secondaryColorHex: "#8AB7E9"),
        Team(name: "Kansas City Current", abbreviation: "KC", sport: "nwsl", isBuiltIn: true, primaryColorHex: "#CF3339", secondaryColorHex: "#62CBC9"),
        Team(name: "North Carolina Courage", abbreviation: "NCC", sport: "nwsl", isBuiltIn: true, primaryColorHex: "#AB0033", secondaryColorHex: "#00416B"),
        Team(name: "Orlando Pride", abbreviation: "ORL", sport: "nwsl", isBuiltIn: true, primaryColorHex: "#FF6600", secondaryColorHex: "#000000"),
        Team(name: "Portland Thorns FC", abbreviation: "POR", sport: "nwsl", isBuiltIn: true, primaryColorHex: "#000000", secondaryColorHex: "#99242B"),
        Team(name: "Racing Louisville FC", abbreviation: "LOU", sport: "nwsl", isBuiltIn: true, primaryColorHex: "#C5B5F2", secondaryColorHex: "#14002F"),
        Team(name: "San Diego Wave FC", abbreviation: "SD", sport: "nwsl", isBuiltIn: true, primaryColorHex: "#032E62", secondaryColorHex: "#21C6D9"),
        Team(name: "Seattle Reign FC", abbreviation: "SEA", sport: "nwsl", isBuiltIn: true, primaryColorHex: "#292431", secondaryColorHex: "#2E407A"),
        Team(name: "Utah Royals", abbreviation: "UTA", sport: "nwsl", isBuiltIn: true, primaryColorHex: "#AE122A", secondaryColorHex: "#FDB71A"),
        Team(name: "Washington Spirit", abbreviation: "WAS", sport: "nwsl", isBuiltIn: true, primaryColorHex: "#000000", secondaryColorHex: "#EDE939"),
    ]
    }
}
