import Foundation

/// Format a cost value respecting user's decimal places setting
func formatCost(_ cost: Double) -> String {
    let decimalPlaces = UserDefaults.standard.integer(forKey: "costDecimalPlaces")
    let places = decimalPlaces == 0 ? 2 : decimalPlaces  // Default to 2 if not set
    return String(format: "$%.\(places)f", cost)
}

/// Aggregated usage for a single day
struct DailyUsage: Identifiable, Equatable {
    let id: String  // YYYY-MM-DD format
    let date: Date
    var tokenCounts: TokenCounts
    var totalCost: Double
    var modelBreakdowns: [ModelBreakdown]

    var formattedCost: String {
        formatCost(totalCost)
    }

    var formattedTokens: String {
        formatTokenCount(tokenCounts.total)
    }

    static let empty = DailyUsage(
        id: "",
        date: Date(),
        tokenCounts: .zero,
        totalCost: 0,
        modelBreakdowns: []
    )
}

/// Monthly aggregated usage
struct MonthlyUsage: Identifiable, Equatable {
    let id: String  // YYYY-MM format
    let month: Date
    var tokenCounts: TokenCounts
    var totalCost: Double
    var modelBreakdowns: [ModelBreakdown]

    var formattedCost: String {
        formatCost(totalCost)
    }

    var formattedMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: month)
    }

    static let empty = MonthlyUsage(
        id: "",
        month: Date(),
        tokenCounts: .zero,
        totalCost: 0,
        modelBreakdowns: []
    )
}

/// Per-model cost breakdown
struct ModelBreakdown: Identifiable, Equatable {
    var id: String { modelName }
    let modelName: String
    var tokenCounts: TokenCounts
    var cost: Double

    var displayName: String {
        // Simplify model name for display
        // "claude-opus-4-20250514" -> "claude-opus-4"
        let parts = modelName.split(separator: "-")
        if parts.count >= 3 {
            // Check if last part is a date (8 digits)
            if let last = parts.last, last.count == 8, Int(last) != nil {
                return parts.dropLast().joined(separator: "-")
            }
        }
        return modelName
    }

    var formattedCost: String {
        formatCost(cost)
    }
}

/// Format token count for display
func formatTokenCount(_ count: Int) -> String {
    if count >= 1_000_000 {
        return String(format: "%.1fM", Double(count) / 1_000_000)
    } else if count >= 1_000 {
        return String(format: "%.1fK", Double(count) / 1_000)
    }
    return "\(count)"
}
