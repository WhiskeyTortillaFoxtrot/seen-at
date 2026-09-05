import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Your data stays with you.")
                    .font(.urbanist(.title3, weight: .semibold))

                policyRow(
                    title: "Stored on your device",
                    body: "Your events, sightings, teams, and photos are kept in the app's on-device library. Migration safety backups are also stored on your device."
                )

                policyRow(
                    title: "No account, no tracking",
                    body: "SeenAt requires no sign-in and collects no analytics, advertising identifiers, or tracking data."
                )

                policyRow(
                    title: "Photos stay local",
                    body: "Sighting photos never leave your device unless you explicitly share or export them."
                )

                policyRow(
                    title: "Diagnostics only when you share them",
                    body: "A diagnostics report is created only when you tap Share Diagnostics in Settings, and you choose what to send."
                )
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .background { StadiumBackdrop(usesDailyImage: true) }
    }

    private func policyRow(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.urbanist(.headline))
            Text(body)
                .font(.urbanist(.body))
                .foregroundStyle(.secondary)
        }
    }
}
