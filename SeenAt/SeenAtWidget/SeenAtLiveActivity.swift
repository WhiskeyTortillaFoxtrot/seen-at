import ActivityKit
import WidgetKit
import SwiftUI

@main
struct SeenAtWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: SeenAtActivityAttributes.self) { context in
            LockScreenView(context: context)
                .widgetURL(URL(string: "seenat://live-tracking/\(context.attributes.eventID.uuidString)"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    TeamColorsView(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    JerseyCountCompact(count: context.state.jerseyCount)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.gameTitle)
                        .font(.urbanist(.caption, weight: .medium))
                        .lineLimit(1)
                }
            } compactLeading: {
                TeamColorsView(context: context)
            } compactTrailing: {
                JerseyCountCompact(count: context.state.jerseyCount)
            } minimal: {
                JerseyCountCompact(count: context.state.jerseyCount)
            }
            .widgetURL(URL(string: "seenat://live-tracking/\(context.attributes.eventID.uuidString)"))
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<SeenAtActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TeamColorDot(hex: context.attributes.homeTeamColor)
                TeamColorDot(hex: context.attributes.awayTeamColor)

                Text(context.attributes.gameTitle)
                    .font(.urbanist(.headline, weight: .bold))
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 4) {
                    Text("\(context.state.jerseyCount)")
                        .font(.urbanist(.title3, weight: .bold))
                    Image(systemName: "tshirt")
                        .font(.urbanist(.caption))
                }
            }

            if !context.state.mostRecentJerseyName.isEmpty {
                HStack(spacing: 4) {
                    Text("Last sighting:")
                        .font(.urbanist(.subheadline))
                        .foregroundStyle(.secondary)
                    Text(context.state.mostRecentJerseyName)
                        .font(.urbanist(.subheadline, weight: .semibold))
                }
            } else {
                Text("No sightings yet")
                    .font(.urbanist(.subheadline))
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .activityBackgroundTint(nil)
    }
}

private struct TeamColorsView: View {
    let context: ActivityViewContext<SeenAtActivityAttributes>

    var body: some View {
        HStack(spacing: -4) {
            TeamColorDot(hex: context.attributes.homeTeamColor)
            TeamColorDot(hex: context.attributes.awayTeamColor)
        }
    }
}

private struct JerseyCountCompact: View {
    let count: Int

    var body: some View {
        HStack(spacing: 2) {
            Text("\(count)")
                .font(.urbanist(.body, weight: .bold))
            Image(systemName: "tshirt")
                .font(.urbanist(.caption2))
        }
    }
}

private struct TeamColorDot: View {
    let hex: String

    var body: some View {
        Circle()
            .fill(color(from: hex))
            .frame(width: 14, height: 14)
            .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
    }

    private func color(from hex: String) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        return Color(red: r, green: g, blue: b)
    }
}
