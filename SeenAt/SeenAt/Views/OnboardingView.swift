import SwiftUI

struct OnboardingView: View {
    @AppStorage(AppPreferences.hasSeenOnboardingKey) private var hasSeenOnboarding = false
    @AppStorage(AppPreferences.favoriteTeamsKey) private var favoriteTeamsString: String = ""
    @State private var currentPage = 0
    @State private var showFavoriteTeams = false
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 72

    private var favoriteCount: Int {
        favoriteTeamsString.split(separator: ",").count
    }

    private var isFinalPage: Bool {
        currentPage == 4
    }

    var body: some View {
        GeometryReader { proxy in
            TabView(selection: $currentPage) {
                welcomePage(in: proxy.size).tag(0)
                howItWorksPage(in: proxy.size).tag(1)
                favoriteTeamsPage(in: proxy.size).tag(2)
                liveActivitiesPage(in: proxy.size).tag(3)
                getStartedPage(in: proxy.size).tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .animation(.easeInOut, value: currentPage)
            .safeAreaInset(edge: .bottom) {
                bottomAction
                    .padding(.top, 12)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
            }
        }
        .background {
            StadiumBackdrop(usesDailyImage: true)
        }
        .sheet(isPresented: $showFavoriteTeams) {
            NavigationStack {
                FavoriteTeamsView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                showFavoriteTeams = false
                            }
                        }
                    }
            }
        }
    }

    private var bottomAction: some View {
        Group {
            if isFinalPage {
                Button("Track Your First Game") {
                    hasSeenOnboarding = true
                }
                .buttonStyle(.borderedProminent)
                .font(.urbanist(.headline))
                .frame(maxWidth: 280, minHeight: 50)
            } else {
                Button("Skip") {
                    hasSeenOnboarding = true
                }
                .font(.urbanist(.subheadline))
                .foregroundStyle(.white.opacity(0.8))
            }
        }
        .animation(.default, value: currentPage)
    }

    private func welcomePage(in size: CGSize) -> some View {
        onboardingPage(in: size, icon: "tshirt.fill", title: "Welcome to SeenAt", description: "Track the jerseys you spot at games. See which teams and players are most popular at the events you attend.")
    }

    private func howItWorksPage(in size: CGSize) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                stepView(icon: "plus.circle.fill", title: "Add a Game", description: "Search for upcoming games by date and league, or enter one manually.")
                stepView(icon: "tshirt", title: "Log Sightings", description: "Tap the big button to record jerseys. Select the team, add player details, and snap a photo.")
                stepView(icon: "chart.bar.fill", title: "View Stats", description: "See your breakdown by team, league, and player. Share summaries with friends.")
            }
            .frame(maxWidth: 340, minHeight: size.height - 120, alignment: .center)
            .padding(.horizontal, 24)
        }
    }

    private func favoriteTeamsPage(in size: CGSize) -> some View {
        onboardingPage(in: size, icon: "star.fill", title: "Pick Your Favorite Teams", description: "Select your favorite teams so SeenAt can highlight their sightings and tailor your stats.") {
            Button {
                showFavoriteTeams = true
            } label: {
                Label(favoriteCount > 0 ? "\(favoriteCount) Team\(favoriteCount == 1 ? "" : "s") Selected" : "Select Favorite Teams", systemImage: favoriteCount > 0 ? "checkmark.circle.fill" : "star")
            }
            .buttonStyle(.borderedProminent)
            .font(.urbanist(.headline))
            .frame(maxWidth: 280, minHeight: 50)
        }
    }

    private func liveActivitiesPage(in size: CGSize) -> some View {
        onboardingPage(in: size, icon: "livephoto.play", title: "Live Activities", description: "Track games in real time with Live Activities. See jersey counts update live on your Lock Screen and in the Dynamic Island.")
    }

    private func getStartedPage(in size: CGSize) -> some View {
        onboardingPage(in: size, icon: "figure.baseball", title: "You're All Set!", description: "Start tracking at your next game. You can revisit this guide anytime from Settings.")
    }

    private func onboardingPage<Accessory: View>(in size: CGSize, icon: String, title: String, description: String, @ViewBuilder accessory: () -> Accessory = { EmptyView() }) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: icon)
                    .font(.system(size: iconSize))
                    .foregroundStyle(Color.accentColor)

                Text(title)
                    .font(.urbanist(.title, weight: .bold))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)

                Text(description)
                    .font(.urbanist(.body))
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 340)

                accessory()
            }
            .frame(maxWidth: .infinity, minHeight: size.height - 120, alignment: .center)
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
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
                    .fixedSize(horizontal: false, vertical: true)
                Text(description)
                    .font(.urbanist(.subheadline))
                    .foregroundStyle(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
