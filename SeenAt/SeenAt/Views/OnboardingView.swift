import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                howItWorksPage.tag(1)
                getStartedPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .animation(.easeInOut, value: currentPage)

            VStack(spacing: 16) {
                if currentPage == 2 {
                    Button("Get Started") {
                        hasSeenOnboarding = true
                    }
                    .buttonStyle(.borderedProminent)
                    .font(.urbanist(.headline))
                    .frame(maxWidth: 280, minHeight: 50)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .padding(.horizontal)
                } else {
                    Button("Skip") {
                        hasSeenOnboarding = true
                    }
                    .font(.urbanist(.subheadline))
                    .foregroundStyle(.secondary)
                    .transition(.opacity)
                }
            }
            .padding(.bottom, 32)
            .animation(.default, value: currentPage)
        }
        .background(.background)
    }

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "tshirt.fill")
                .font(.system(size: 72))
                .foregroundStyle(Color.accentColor)

            Text("Welcome to SeenAt")
                .font(.urbanist(.title, weight: .bold))
                .multilineTextAlignment(.center)

            Text("Track the jerseys you spot at games. See which teams and players are most popular at the events you attend.")
                .font(.urbanist(.body))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
    }

    private var howItWorksPage: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(alignment: .leading, spacing: 24) {
                stepView(icon: "plus.circle.fill", title: "Add a Game", description: "Search for upcoming games by date and league, or enter one manually.")
                stepView(icon: "tshirt", title: "Log Sightings", description: "Tap the big button to record jerseys. Select the team, add player details, and snap a photo.")
                stepView(icon: "chart.bar.fill", title: "View Stats", description: "See your breakdown by team, league, and player. Share summaries with friends.")
            }
            .padding(.horizontal, 32)

            Spacer()
        }
    }

    private var getStartedPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "figure.baseball")
                .font(.system(size: 72))
                .foregroundStyle(Color.accentColor)

            Text("You're All Set!")
                .font(.urbanist(.title, weight: .bold))
                .multilineTextAlignment(.center)

            Text("Start tracking at your next game. You can revisit this guide anytime from Settings.")
                .font(.urbanist(.body))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()
        }
    }

    private func stepView(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.urbanist(.title2))
                .foregroundStyle(Color.accentColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.urbanist(.headline))
                Text(description)
                    .font(.urbanist(.subheadline))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
