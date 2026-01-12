import Foundation

/// Raw usage entry from Claude Code JSONL files
struct UsageEntry: Codable, Identifiable {
    var id: String { "\(timestamp.timeIntervalSince1970)-\(requestId ?? "")-\(message?.id ?? "")" }

    let timestamp: Date
    let sessionId: String?
    let message: MessageData?
    let costUSD: Double?
    let requestId: String?
    let cwd: String?
    let version: String?
    let isApiErrorMessage: Bool?

    struct MessageData: Codable {
        let model: String?
        let id: String?
        let usage: TokenUsage?
        let content: [ContentBlock]?
    }

    struct TokenUsage: Codable {
        let input_tokens: Int
        let output_tokens: Int
        let cache_creation_input_tokens: Int?
        let cache_read_input_tokens: Int?
    }

    struct ContentBlock: Codable {
        let text: String?
    }

    /// Check if this is a valid usage entry with token data
    var hasUsageData: Bool {
        message?.usage != nil && message?.usage?.output_tokens ?? 0 > 0
    }

    /// Check if this is a Claude model
    var isClaudeModel: Bool {
        guard let model = message?.model else { return false }
        return model.lowercased().contains("claude")
    }

    /// Get total tokens for this entry
    var totalTokens: Int {
        guard let usage = message?.usage else { return 0 }
        return usage.input_tokens
            + usage.output_tokens
            + (usage.cache_creation_input_tokens ?? 0)
            + (usage.cache_read_input_tokens ?? 0)
    }
}

/// Token counts aggregate
struct TokenCounts: Equatable {
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheCreationTokens: Int = 0
    var cacheReadTokens: Int = 0

    var total: Int {
        inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
    }

    mutating func add(_ entry: UsageEntry) {
        guard let usage = entry.message?.usage else { return }
        inputTokens += usage.input_tokens
        outputTokens += usage.output_tokens
        cacheCreationTokens += usage.cache_creation_input_tokens ?? 0
        cacheReadTokens += usage.cache_read_input_tokens ?? 0
    }

    mutating func add(_ other: TokenCounts) {
        inputTokens += other.inputTokens
        outputTokens += other.outputTokens
        cacheCreationTokens += other.cacheCreationTokens
        cacheReadTokens += other.cacheReadTokens
    }

    static let zero = TokenCounts()
}
