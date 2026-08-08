import SwiftUI
import Charts

enum TrendGranularity: String, CaseIterable, Identifiable {
    case perGame = "Per Game"
    case perMonth = "Per Month"
    case perYear = "Per Year"

    var id: String { rawValue }
}

struct StatsTrendChart: View {
    let events: [Event]
    @Binding var granularity: TrendGranularity

    private var chartData: [(label: String, count: Int)] {
        switch granularity {
        case .perGame:
            return events
                .sorted(by: { $0.date < $1.date })
                .enumerated()
                .map { (index, event) in
                    let formatter = DateFormatter()
                    formatter.dateFormat = "MMM d"
                    return (formatter.string(from: event.date), event.sightings.count)
                }

        case .perMonth:
            let calendar = Calendar.current
            let grouped = Dictionary(grouping: events) { event in
                let components = calendar.dateComponents([.year, .month], from: event.date)
                return calendar.date(from: components) ?? event.date
            }
            let sortedDates = grouped.keys.sorted()
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM yyyy"
            return sortedDates.map { date in
                let count = grouped[date]?.reduce(0) { $0 + $1.sightings.count } ?? 0
                return (formatter.string(from: date), count)
            }

        case .perYear:
            let calendar = Calendar.current
            let grouped = Dictionary(grouping: events) { event in
                calendar.component(.year, from: event.date)
            }
            let sortedYears = grouped.keys.sorted()
            return sortedYears.map { year in
                let count = grouped[year]?.reduce(0) { $0 + $1.sightings.count } ?? 0
                return ("\(year)", count)
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trend Over Time")
                .font(.urbanist(.headline))

            Picker("Granularity", selection: $granularity) {
                ForEach(TrendGranularity.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)

            if chartData.isEmpty {
                Text("No trend data")
                    .font(.urbanist(.subheadline))
                    .foregroundStyle(.secondary)
                    .frame(height: 140)
            } else {
                Chart(chartData, id: \.label) { item in
                    BarMark(
                        x: .value("Date", item.label),
                        y: .value("Jerseys", item.count)
                    )
                    .foregroundStyle(Color.accentColor)
                }
                .chartYScale(domain: 0...(chartData.map(\.count).max() ?? 1))
                .frame(height: 180)
            }
        }
        .padding()
        .liquidGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
