import Foundation

extension String {
    func parsedTeams() -> (away: String, home: String)? {
        let parts = components(separatedBy: " @ ")
        guard parts.count == 2 else { return nil }
        let away = parts[0].trimmingCharacters(in: .whitespaces)
        let home = parts[1].trimmingCharacters(in: .whitespaces)
        guard !away.isEmpty && !home.isEmpty else { return nil }
        return (away, home)
    }
}
