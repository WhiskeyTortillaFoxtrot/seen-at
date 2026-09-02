import Foundation

struct LeagueGame: Identifiable {
    let id: String
    let awayTeam: String
    let homeTeam: String
    let venueName: String
    let dateString: String
    let league: String
    let url: URL?
    let dayNight: String?

    var title: String { "\(awayTeam) @ \(homeTeam)" }
}

extension LeagueGame {
    /// Feeds provide links in two shapes: absolute URLs (ESPN) and site-relative paths
    /// (NHL's `/gamecenter/...`). Every league resolves its links through this helper so
    /// `url` is always absolute, or nil when the feed provides no usable link. Only paths
    /// rooted at the league's own host are accepted, so a malformed or hostile value can
    /// never resolve to a different domain.
    static func resolveGameLink(_ raw: String?, base: URL) -> URL? {
        guard let raw, !raw.isEmpty else { return nil }
        if let absolute = URL(string: raw), absolute.scheme == "http" || absolute.scheme == "https" {
            return absolute
        }
        guard raw.hasPrefix("/"),
              let resolved = URL(string: raw, relativeTo: base)?.absoluteURL,
              resolved.host == base.host
        else { return nil }
        return resolved
    }
}
