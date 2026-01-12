import SwiftUI
import Charts

/// Bar chart showing daily usage for the last 7 days
struct DailyChartView: View {
    let dailyUsage: [DailyUsage]

    var body: some View {
        Chart(dailyUsage) { day in
            BarMark(
                x: .value("Day", day.date, unit: .day),
                y: .value("Cost", day.totalCost)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [.blue, .blue.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(3)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    .font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisValueLabel {
                    if let cost = value.as(Double.self) {
                        Text("$\(Int(cost))")
                            .font(.caption2)
                    }
                }
            }
        }
        .chartYScale(domain: 0...(maxCost * 1.1))
    }

    private var maxCost: Double {
        max(dailyUsage.map(\.totalCost).max() ?? 1, 1)
    }
}

/// Monthly bar chart
struct MonthlyChartView: View {
    let monthlyUsage: [MonthlyUsage]

    var body: some View {
        Chart(monthlyUsage) { month in
            BarMark(
                x: .value("Month", month.month, unit: .month),
                y: .value("Cost", month.totalCost)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [.purple, .purple.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .cornerRadius(4)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .month)) { value in
                AxisValueLabel(format: .dateTime.month(.abbreviated))
                    .font(.caption2)
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisValueLabel {
                    if let cost = value.as(Double.self) {
                        Text("$\(Int(cost))")
                            .font(.caption2)
                    }
                }
            }
        }
    }
}
