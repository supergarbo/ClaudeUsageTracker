import SwiftUI

/// Display current 5-hour billing block status
struct BlockStatusView: View {
    let block: SessionBlock
    @State private var now = Date()

    // Timer to update time remaining
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("CURRENT BLOCK")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if block.isActive {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 6, height: 6)
                        Text("Active")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                } else {
                    Text("Expired")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Cost and time remaining
            HStack(alignment: .firstTextBaseline) {
                Text(block.formattedCost)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .monospacedDigit()

                Spacer()

                if block.isActive {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatTimeRemaining())
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .monospacedDigit()
                        Text("remaining")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.blue, .blue.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * currentProgress)
                }
            }
            .frame(height: 6)

            // Token count
            HStack {
                Text("\(formatTokenCount(block.tokenCounts.total)) tokens")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(formatTimeRange())
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .onReceive(timer) { _ in
            now = Date()
        }
    }

    private var currentProgress: Double {
        let totalDuration = block.endTime.timeIntervalSince(block.startTime)
        let elapsed = now.timeIntervalSince(block.startTime)
        return min(max(elapsed / totalDuration, 0), 1)
    }

    private func formatTimeRemaining() -> String {
        let remaining = block.endTime.timeIntervalSince(now)
        guard remaining > 0 else { return "0m" }

        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func formatTimeRange() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"

        let start = formatter.string(from: block.startTime)
        let end = formatter.string(from: block.endTime)

        return "\(start) - \(end)"
    }
}
