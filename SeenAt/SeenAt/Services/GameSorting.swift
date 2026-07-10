import Foundation

func sortedGames(_ games: [LeagueGame], favoriteTeamNames: [String]) -> [LeagueGame] {
    guard !favoriteTeamNames.isEmpty else { return games }
    return games.sorted { a, b in
        let aIsFav = favoriteTeamNames.contains { a.title.localizedCaseInsensitiveContains($0) }
        let bIsFav = favoriteTeamNames.contains { b.title.localizedCaseInsensitiveContains($0) }
        return aIsFav && !bIsFav
    }
}
