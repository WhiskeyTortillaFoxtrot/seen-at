import Foundation
import SwiftUI
import UniformTypeIdentifiers
import SwiftData

struct ExportService {
    static func generateSummary(for event: Event) -> String {
        var lines: [String] = []
        lines.append("📍 SeenAt — Game Summary")
        lines.append("")
        lines.append(event.title)
        if let venue = event.venue {
            lines.append("📍 \(venue)")
        }
        lines.append("📅 \(event.date.formatted(date: .abbreviated, time: .omitted))")
        lines.append("")

        if event.totalCount == 0 {
            lines.append("No Jerseys Sighted Yet")
        } else {
            lines.append("Total jerseys seen: \(event.totalCount)")

            if let popular = event.teamBreakdown.first {
                lines.append("Most popular team: \(popular.team.name) (\(popular.count))")
            }

            if !event.sightings.contains(where: { $0.isPlayerSighting }) {
                lines.append("No player jerseys recorded")
            } else if let popular = event.playerBreakdown.first {
                lines.append("Most popular jersey: \(popular.team.abbreviation) \(popular.playerName) (\(popular.count))")
            }
        }

        lines.append("")
        lines.append("——")
        lines.append("via SeenAt")

        return lines.joined(separator: "\n")
    }

    @MainActor
    static func generateSummaryImage(for event: Event, awayTeamColor: Color?, homeTeamColor: Color?, size: CGSize) -> UIImage? {
        let view = SummaryCardView(event: event, size: size, awayTeamColor: awayTeamColor, homeTeamColor: homeTeamColor)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1.0
        return renderer.uiImage
    }

    static func generateAllDataCSV(context: ModelContext) throws -> String {
        let events = try context.fetch(FetchDescriptor<Event>(sortBy: [SortDescriptor(\Event.date, order: .reverse)]))

        let header = "Event Title,Date,Venue,Watch Location,Total Sightings,Team,First Name,Last Name,Player Number"
        var rows: [String] = []

        for event in events {
            let title = escapeCSV(event.title)
            let date = event.date.formatted(date: .numeric, time: .omitted)
            let venue = escapeCSV(event.venue ?? "")
            let total = "\(event.totalCount)"
            let watchLocation = event.watchLocation?.rawValue ?? "stadium"

            if event.sightings.isEmpty {
                rows.append("\(title),\(date),\(venue),\(watchLocation),\(total),,,,")
            } else {
                for sighting in event.sightings {
                    let team = escapeCSV(sighting.team?.name ?? "")
                    let first = escapeCSV(sighting.firstName ?? "")
                    let last = escapeCSV(sighting.lastName ?? "")
                    let number = escapeCSV(sighting.playerNumber ?? "")
                    rows.append("\(title),\(date),\(venue),\(watchLocation),\(total),\(team),\(first),\(last),\(number)")
                }
            }
        }

        return ([header] + rows).joined(separator: "\n") + "\n"
    }

    /// Neutralizes spreadsheet formulas per OWASP CSV injection guidance (prefix `=` `+`
    /// `-` `@` with an apostrophe), then applies RFC 4180 quoting. The prefix goes on the
    /// raw value *before* quoting so the apostrophe stays inside the quotes; quoting first
    /// and prefixing after would produce `'\"=SUM(1, 2)\"'`, which parsers reject and which
    /// shifts columns on values containing commas.
    private static func escapeCSV(_ value: String) -> String {
        var escaped = value
        if let first = escaped.first, first == "=" || first == "+" || first == "-" || first == "@" {
            escaped = "'" + escaped
        }
        if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") {
            escaped = "\"\(escaped.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return escaped
    }
}
