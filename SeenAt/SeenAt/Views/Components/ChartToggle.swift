import SwiftUI

struct ChartToggle: View {
    @Binding var usePieChart: Bool

    var body: some View {
        Picker("Chart Style", selection: $usePieChart) {
            Image(systemName: "chart.bar.fill")
                .accessibilityLabel("Bar Chart")
                .tag(false)
            Image(systemName: "chart.pie.fill")
                .accessibilityLabel("Pie Chart")
                .tag(true)
        }
        .pickerStyle(.segmented)
    }
}
