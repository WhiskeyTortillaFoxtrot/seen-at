import SwiftUI

struct SummaryCardView: View {
    let event: Event
    let size: CGSize
    let awayTeamColor: Color?
    let homeTeamColor: Color?

    private var mostPopularTeam: (team: Team, count: Int)? {
        event.teamBreakdown.first
    }

    private var titleFont: CGFloat { size.height * 0.055 }
    private var metaFont: CGFloat { size.height * 0.035 }
    private var labelFont: CGFloat { size.height * 0.04 }
    private var countFont: CGFloat { size.height * 0.22 }
    private var teamFont: CGFloat { size.height * 0.22 }
    private var emptyFont: CGFloat { size.height * 0.06 }

    var body: some View {
        VStack(spacing: 0) {
            titleRow
                .frame(height: size.height * 0.30)

            if event.totalCount == 0 {
                emptyState
                    .frame(height: size.height * 0.70)
            } else {
                labelsRow
                    .frame(height: size.height * 0.15)
                valuesRow
                    .frame(height: size.height * 0.55)
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
        } else if let away = awayTeamColor, let home = homeTeamColor {
            GeometryReader { geo in
                let topX = geo.size.width * 0.4
                let bottomX = geo.size.width * 0.6

                Path { path in
                    path.move(to: CGPoint(x: topX, y: 0))
                    path.addLine(to: CGPoint(x: geo.size.width, y: 0))
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                    path.addLine(to: CGPoint(x: bottomX, y: geo.size.height))
                    path.closeSubpath()
                }
                .fill(away)

                Path { path in
                    path.move(to: .zero)
                    path.addLine(to: CGPoint(x: topX, y: 0))
                    path.addLine(to: CGPoint(x: bottomX, y: geo.size.height))
                    path.addLine(to: CGPoint(x: 0, y: geo.size.height))
                    path.closeSubpath()
                }
                .fill(home)
            }
        } else if let single = awayTeamColor ?? homeTeamColor {
            LinearGradient(
                colors: [single, single.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.5), Color.accentColor.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var titleRow: some View {
        VStack(spacing: 4) {
            VStack(spacing: 2) {
                if let away = event.awayTeam {
                    Text(away)
                        .font(.urbanist(size: titleFont, weight: .bold))
                        .foregroundStyle(.white)
                }
                if let home = event.homeTeam {
                    Text("@ \(home)")
                        .font(.urbanist(size: titleFont, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .multilineTextAlignment(.center)
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
        .frame(maxHeight: .infinity, alignment: .bottom)
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
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var emptyState: some View {
        Text("No Jerseys Sighted Yet")
            .font(.urbanist(size: emptyFont, weight: .semibold))
            .foregroundStyle(.white.opacity(0.8))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
