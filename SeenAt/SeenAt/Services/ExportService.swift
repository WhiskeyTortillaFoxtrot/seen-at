import Foundation
import SwiftUI
import UniformTypeIdentifiers
import SwiftData

struct ExportService {
    static func generateSummary(for event: Event) -> String {
        var lines: [String] = []
        lines.append("📍 SeenAt — Game Summary")
        lines.append("")
        lines.append("\(event.title)")
        if let venue = event.venue {
            lines.append("📍 \(venue)")
        }
        lines.append("📅 \(event.date.formatted(date: .abbreviated, time: .omitted))")
        lines.append("")
        lines.append("Total jerseys seen: \(event.totalCount)")
        lines.append("")

        let teams = event.teamBreakdown
        if !teams.isEmpty {
            lines.append("━━━ By Team ━━━")
            for (team, count) in teams {
                let pct = Double(count) / Double(event.totalCount) * 100
                lines.append("  \(team.name): \(count) (\(String(format: "%.1f", pct))%)")
            }
            lines.append("")
        }

        let players = event.playerBreakdown
        if !players.isEmpty {
            lines.append("━━━ By Player ━━━")
            for (team, player, count) in players {
                lines.append("  \(team.abbreviation) \(player): \(count)")
            }
            lines.append("")
        }

        lines.append("——")
        lines.append("via SeenAt")

        return lines.joined(separator: "\n")
    }

    static func generateAllDataCSV(context: ModelContext) -> String {
        let events = (try? context.fetch(FetchDescriptor<Event>(sortBy: [SortDescriptor(\Event.date, order: .reverse)]))) ?? []

        var csv = "Event Title,Date,Venue,Watch Location,Total Sightings,Team,First Name,Last Name,Player Number\n"

        for event in events {
            let title = escapeCSV(event.title)
            let date = event.date.formatted(date: .numeric, time: .omitted)
            let venue = escapeCSV(event.venue ?? "")
            let total = "\(event.totalCount)"
            let watchLocation = event.watchLocation?.rawValue ?? "stadium"

            if event.sightings.isEmpty {
                csv += "\(title),\(date),\(venue),\(watchLocation),\(total),,,,\n"
            } else {
                for sighting in event.sightings {
                    let team = escapeCSV(sighting.team?.name ?? "")
                    let first = escapeCSV(sighting.firstName ?? "")
                    let last = escapeCSV(sighting.lastName ?? "")
                    let number = escapeCSV(sighting.playerNumber ?? "")
                    csv += "\(title),\(date),\(venue),\(watchLocation),\(total),\(team),\(first),\(last),\(number)\n"
                }
            }
        }

        return csv
    }

    private static func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
