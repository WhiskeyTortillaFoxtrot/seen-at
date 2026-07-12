import SwiftUI

struct SummaryCardView: View {
    let event: Event
    let size: CGSize

    private var topTeamColors: [Color] {
        let teams = event.teamBreakdown.prefix(2).map { $0.team.primaryColor }
        return teams.isEmpty ? [Color.accentColor] : teams
    }

    private var mostPopularTeam: (team: Team, count: Int)? {
        event.teamBreakdown.first
    }

    private var titleFont: CGFloat { size.height * 0.055 }
    private var metaFont: CGFloat { size.height * 0.035 }
    private var labelFont: CGFloat { size.height * 0.04 }
    private var countFont: CGFloat { size.height * 0.16 }
    private var teamFont: CGFloat { size.height * 0.12 }
    private var emptyFont: CGFloat { size.height * 0.06 }

    var body: some View {
        VStack(spacing: 0) {
            titleRow
                .frame(height: size.height * 0.25)

            if event.totalCount == 0 {
                emptyState
                    .frame(height: size.height * 0.75)
            } else {
                labelsRow
                    .frame(height: size.height * 0.25)
                valuesRow
                    .frame(height: size.height * 0.5)
            }
        }
        .frame(width: size.width, height: size.height)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 0))
    }

    @ViewBuilder
    private var background: some View {
        if event.watchLocation != .tv, let venue = event.venue, let photo = StadiumPhotoService.image(for: venue) {
            ZStack {
                photo
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                Color.black.opacity(0.5)
            }
        } else {
            LinearGradient(
                colors: topTeamColors.map { $0.opacity(0.5) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var titleRow: some View {
        VStack(spacing: 6) {
            Text(event.title)
                .font(.urbanist(size: titleFont, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.5)

            HStack(spacing: 0) {
                if let venue = event.venue {
                    Text(venue)
                        .font(.urbanist(size: metaFont))
                        .foregroundStyle(.white.opacity(0.8))
                    Text("  |  ")
                        .font(.urbanist(size: metaFont))
                        .foregroundStyle(.white.opacity(0.8))
                }
                Text(event.date.formatted(date: .long, time: .omitted))
                    .font(.urbanist(size: metaFont))
                    .foregroundStyle(.white.opacity(0.8))
            }
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .padding(.horizontal)
        }
        .frame(maxHeight: .infinity)
    }

    private var labelsRow: some View {
        HStack(alignment: .center) {
            Text("Jerseys Seen")
                .font(.urbanist(size: labelFont, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .frame(maxWidth: .infinity)

            if mostPopularTeam != nil {
                Text("Most Popular Team")
                    .font(.urbanist(size: labelFont, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
    }

    private var valuesRow: some View {
        HStack(alignment: .center) {
            Text("\(event.totalCount)")
                .font(.urbanist(size: countFont, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)

            if let popular = mostPopularTeam {
                VStack(spacing: 4) {
                    Text(popular.team.abbreviation)
                        .font(.urbanist(size: teamFont, weight: .bold))
                        .foregroundStyle(.white)
                    Text(popular.team.sport.uppercased())
                        .font(.urbanist(size: metaFont, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
    }

    private var emptyState: some View {
        Text("No Jerseys Sighted Yet")
            .font(.urbanist(size: emptyFont, weight: .semibold))
            .foregroundStyle(.white.opacity(0.8))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
