import Foundation

/// A 5-hour billing block (Claude's usage window)
struct SessionBlock: Identifiable, Equatable {
    let id: String  // ISO timestamp of block start
    let startTime: Date
    let endTime: Date  // startTime + 5 hours
    let isActive: Bool
    var tokenCounts: TokenCounts
    var costUSD: Double
    var models: [String]

    /// Time remaining in this block (nil if not active)
    var timeRemaining: TimeInterval? {
        guard isActive else { return nil }
        let remaining = endTime.timeIntervalSince(Date())
        return remaining > 0 ? remaining : nil
    }

    /// Progress through the 5-hour window (0.0 to 1.0)
    var elapsedProgress: Double {
        let totalDuration = endTime.timeIntervalSince(startTime)
        let elapsed = Date().timeIntervalSince(startTime)
        return min(max(elapsed / totalDuration, 0), 1)
    }

    var formattedCost: String {
        String(format: "$%.2f", costUSD)
    }

    var formattedTimeRemaining: String {
        guard let remaining = timeRemaining else { return "Expired" }
        let hours = Int(remaining) / 3600
        let minutes = (Int(remaining) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m left"
        }
        return "\(minutes)m left"
    }

    static let empty = SessionBlock(
        id: "",
        startTime: Date(),
        endTime: Date(),
        isActive: false,
        tokenCounts: .zero,
        costUSD: 0,
        models: []
    )
}
