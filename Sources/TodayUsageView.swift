import SwiftUI

/// Display today's usage summary
struct TodayUsageView: View {
    let usage: DailyUsage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TODAY")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline) {
                Text(usage.formattedCost)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(usage.formattedTokens)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("tokens")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            // Model breakdown (top 3)
            if !usage.modelBreakdowns.isEmpty {
                VStack(spacing: 4) {
                    ForEach(usage.modelBreakdowns.prefix(3)) { model in
                        HStack {
                            Circle()
                                .fill(colorForModel(model.modelName))
                                .frame(width: 6, height: 6)

                            Text(model.displayName)
                                .font(.caption)
                                .lineLimit(1)

                            Spacer()

                            Text(model.formattedCost)
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func colorForModel(_ name: String) -> Color {
        if name.contains("opus") {
            return .purple
        } else if name.contains("sonnet") {
            return .blue
        } else if name.contains("haiku") {
            return .teal
        }
        return .gray
    }
}
