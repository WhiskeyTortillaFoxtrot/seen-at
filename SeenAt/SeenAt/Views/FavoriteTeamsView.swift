import SwiftUI
import SwiftData

struct FavoriteTeamsView: View {
    @AppStorage("favoriteTeams") private var favoriteTeamsString: String = ""

    @Query(sort: \Team.name) private var allTeams: [Team]

    private var favoriteNames: Set<String> {
        Set(favoriteTeamsString.split(separator: ",").map(String.init))
    }

    private var teamsByLeague: [(String, [Team])] {
        Dictionary(grouping: allTeams) { $0.sport }
            .map { (label(for: $0.key), $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.0 < $1.0 }
    }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(teamsByLeague, id: \.0) { league, _ in
                                Button(league) {
                                    withAnimation {
                                        proxy.scrollTo(league, anchor: .top)
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.accentColor)
                                .controlSize(.small)
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 6)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                ForEach(teamsByLeague, id: \.0) { league, teams in
                    Section(league) {
                        ForEach(teams) { team in
                            Button {
                                toggle(team.name)
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(team.primaryColor)
                                        .frame(width: 12, height: 12)
                                    Text(team.name)
                                    Spacer()
                                    if favoriteNames.contains(team.name) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Color.accentColor)
                                    }
                                }
                            }
                        }
                    }
                    .id(league)
                }
            }
        }
        .navigationTitle("Favorite Teams")
        .onAppear(perform: migrateOldFavorite)
    }

    private func toggle(_ name: String) {
        var names = favoriteNames
        if names.contains(name) {
            names.remove(name)
        } else {
            names.insert(name)
        }
        favoriteTeamsString = names.sorted().joined(separator: ",")
    }

    private func migrateOldFavorite() {
        guard favoriteTeamsString.isEmpty else { return }
        guard let oldFavorite = UserDefaults.standard.string(forKey: "favoriteTeam"),
              !oldFavorite.isEmpty
        else { return }
        favoriteTeamsString = oldFavorite
        UserDefaults.standard.removeObject(forKey: "favoriteTeam")
    }

    private func label(for sport: String) -> String {
        switch sport {
        case "mlb": return "MLB"
        case "nba": return "NBA"
        case "nfl": return "NFL"
        case "nhl": return "NHL"
        case "lovb": return "LOVB"
        case "mls": return "MLS"
        default: return sport.uppercased()
        }
    }
}
