import Foundation

/// Pricing data for a single model from LiteLLM
struct ModelPricing: Codable, Equatable {
    let inputCostPerToken: Double
    let outputCostPerToken: Double
    let cacheReadInputTokenCost: Double?
    let cacheCreationInputTokenCost: Double?
    let maxInputTokens: Int?
    let maxOutputTokens: Int?

    enum CodingKeys: String, CodingKey {
        case inputCostPerToken = "input_cost_per_token"
        case outputCostPerToken = "output_cost_per_token"
        case cacheReadInputTokenCost = "cache_read_input_token_cost"
        case cacheCreationInputTokenCost = "cache_creation_input_token_cost"
        case maxInputTokens = "max_input_tokens"
        case maxOutputTokens = "max_output_tokens"
    }

    /// Calculate cost for given token counts
    func calculateCost(tokens: TokenCounts) -> Double {
        var cost = 0.0

        // Input tokens
        cost += Double(tokens.inputTokens) * inputCostPerToken

        // Output tokens
        cost += Double(tokens.outputTokens) * outputCostPerToken

        // Cache creation tokens (typically 1.25x input cost if not specified)
        if let cacheCreationCost = cacheCreationInputTokenCost {
            cost += Double(tokens.cacheCreationTokens) * cacheCreationCost
        } else {
            cost += Double(tokens.cacheCreationTokens) * inputCostPerToken * 1.25
        }

        // Cache read tokens (typically 0.1x input cost if not specified)
        if let cacheReadCost = cacheReadInputTokenCost {
            cost += Double(tokens.cacheReadTokens) * cacheReadCost
        } else {
            cost += Double(tokens.cacheReadTokens) * inputCostPerToken * 0.1
        }

        return cost
    }
}

/// Container for all pricing data
struct PricingData: Codable {
    let models: [String: ModelPricing]
    let fetchedAt: Date

    /// Check if pricing data is stale (older than 24 hours)
    var isStale: Bool {
        Date().timeIntervalSince(fetchedAt) > 24 * 60 * 60
    }
}
