import Foundation

/// Service for fetching and caching model pricing from LiteLLM
actor PricingService {
    static let shared = PricingService()

    private let liteLLMURL = URL(string: "https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json")!
    private var cachedPricing: PricingData?
    private var pricingMap: [String: ModelPricing] = [:]

    private var cacheURL: URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let appCacheDir = cacheDir.appendingPathComponent("ClaudeUsageTracker", isDirectory: true)
        try? FileManager.default.createDirectory(at: appCacheDir, withIntermediateDirectories: true)
        return appCacheDir.appendingPathComponent("pricing.json")
    }

    /// Load pricing data (from cache or network)
    func loadPricing() async throws {
        // Try to load from cache first
        if let cached = loadFromCache(), !cached.isStale {
            cachedPricing = cached
            pricingMap = cached.models
            return
        }

        // Fetch from network
        do {
            try await fetchFromNetwork()
        } catch {
            // Fall back to cache even if stale
            if let cached = loadFromCache() {
                cachedPricing = cached
                pricingMap = cached.models
            } else {
                throw error
            }
        }
    }

    /// Fetch fresh pricing from LiteLLM
    private func fetchFromNetwork() async throws {
        let (data, _) = try await URLSession.shared.data(from: liteLLMURL)

        // Parse the LiteLLM JSON format
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw PricingError.invalidFormat
        }

        var models: [String: ModelPricing] = [:]

        for (key, value) in json {
            // Only keep Claude models (prefixed with "claude/" or containing "claude")
            guard key.lowercased().contains("claude"),
                  let modelData = value as? [String: Any] else {
                continue
            }

            // Parse pricing fields
            guard let inputCost = modelData["input_cost_per_token"] as? Double,
                  let outputCost = modelData["output_cost_per_token"] as? Double else {
                continue
            }

            let pricing = ModelPricing(
                inputCostPerToken: inputCost,
                outputCostPerToken: outputCost,
                cacheReadInputTokenCost: modelData["cache_read_input_token_cost"] as? Double,
                cacheCreationInputTokenCost: modelData["cache_creation_input_token_cost"] as? Double,
                maxInputTokens: modelData["max_input_tokens"] as? Int,
                maxOutputTokens: modelData["max_output_tokens"] as? Int
            )

            // Store with normalized key (remove "claude/" prefix if present)
            let normalizedKey = key.replacingOccurrences(of: "claude/", with: "")
            models[normalizedKey] = pricing
        }

        let pricingData = PricingData(models: models, fetchedAt: Date())
        cachedPricing = pricingData
        pricingMap = models

        // Save to cache
        saveToCache(pricingData)
    }

    /// Get pricing for a specific model
    func getPricing(for modelName: String) -> ModelPricing? {
        // Try exact match first
        if let pricing = pricingMap[modelName] {
            return pricing
        }

        // Try normalized name (remove date suffix like "-20250514")
        let normalized = normalizeModelName(modelName)
        if let pricing = pricingMap[normalized] {
            return pricing
        }

        // Try partial match
        for (key, pricing) in pricingMap {
            if modelName.contains(key) || key.contains(normalized) {
                return pricing
            }
        }

        return nil
    }

    /// Calculate cost for an entry using dynamic pricing
    func calculateCost(entry: UsageEntry) -> Double {
        guard let model = entry.message?.model,
              let usage = entry.message?.usage else {
            return entry.costUSD ?? 0
        }

        // If we have pre-calculated cost and no pricing data, use it
        guard let pricing = getPricing(for: model) else {
            return entry.costUSD ?? 0
        }

        let tokens = TokenCounts(
            inputTokens: usage.input_tokens,
            outputTokens: usage.output_tokens,
            cacheCreationTokens: usage.cache_creation_input_tokens ?? 0,
            cacheReadTokens: usage.cache_read_input_tokens ?? 0
        )

        return pricing.calculateCost(tokens: tokens)
    }

    /// Calculate cost for token counts and model
    func calculateCost(tokens: TokenCounts, model: String) -> Double {
        guard let pricing = getPricing(for: model) else {
            return 0
        }
        return pricing.calculateCost(tokens: tokens)
    }

    // MARK: - Caching

    private func loadFromCache() -> PricingData? {
        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: cacheURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(PricingData.self, from: data)
        } catch {
            print("Failed to load pricing cache: \(error)")
            return nil
        }
    }

    private func saveToCache(_ pricing: PricingData) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(pricing)
            try data.write(to: cacheURL)
        } catch {
            print("Failed to save pricing cache: \(error)")
        }
    }

    // MARK: - Helpers

    private func normalizeModelName(_ name: String) -> String {
        // Remove date suffix like "-20250514"
        let parts = name.split(separator: "-")
        if let last = parts.last, last.count == 8, Int(last) != nil {
            return parts.dropLast().joined(separator: "-")
        }
        return name
    }
}

enum PricingError: Error {
    case invalidFormat
    case networkError
}
