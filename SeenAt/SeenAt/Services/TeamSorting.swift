import Foundation

func sortedTeams(_ allTeams: [Team], searchText: String, eventTitle: String, favoriteTeamNames: [String]) -> [Team] {
    let teams = searchText.isEmpty ? allTeams : allTeams.filter {
        $0.name.localizedCaseInsensitiveContains(searchText) ||
        $0.abbreviation.localizedCaseInsensitiveContains(searchText)
    }

    let gameTeamNames = eventTitle.components(separatedBy: " @ ").map { $0.trimmingCharacters(in: .whitespaces) }
    let gameTeams = teams.filter { gameTeamNames.contains($0.name) }
    let gameTeamOrder = gameTeams.sorted { a, b in
        let aIdx = gameTeamNames.firstIndex(of: a.name) ?? 0
        let bIdx = gameTeamNames.firstIndex(of: b.name) ?? 0
        return aIdx < bIdx
    }

    let favoriteSet = Set(favoriteTeamNames)
    let favoriteTeams = teams.filter { favoriteSet.contains($0.name) }

    var result: [Team] = []

    for team in gameTeamOrder {
        if favoriteSet.contains(team.name), !result.contains(where: { $0.id == team.id }) {
            result.append(team)
        }
    }

    for team in gameTeamOrder {
        if !result.contains(where: { $0.id == team.id }) {
            result.append(team)
        }
    }

    for team in favoriteTeams {
        if !result.contains(where: { $0.id == team.id }) {
            result.append(team)
        }
    }

    let otherTeams = teams.filter { team in !result.contains(where: { $0.id == team.id }) }
    result.append(contentsOf: otherTeams)

    return result
}
