import SwiftUI

struct ChartToggle: View {
    @Binding var usePieChart: Bool

    var body: some View {
        Picker("Chart Style", selection: $usePieChart) {
            Image(systemName: "chart.bar.fill").tag(false)
            Image(systemName: "chart.pie.fill").tag(true)
        }
        .pickerStyle(.segmented)
    }
}
