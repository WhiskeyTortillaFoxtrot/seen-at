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
