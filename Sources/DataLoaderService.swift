import Foundation

/// Service for loading usage data from Claude Code JSONL files
actor DataLoaderService {
    static let shared = DataLoaderService()

    private let fileManager = FileManager.default

    /// Get all Claude data directory paths
    func getClaudePaths() -> [URL] {
        var paths: [URL] = []
        let home = fileManager.homeDirectoryForCurrentUser

        // Primary location (XDG config)
        let configPath = home.appendingPathComponent(".config/claude/projects")
        if fileManager.fileExists(atPath: configPath.path) {
            paths.append(configPath)
        }

        // Legacy location
        let legacyPath = home.appendingPathComponent(".claude/projects")
        if fileManager.fileExists(atPath: legacyPath.path) {
            paths.append(legacyPath)
        }

        // Environment variable override
        if let envPath = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"] {
            for component in envPath.split(separator: ",") {
                let url = URL(fileURLWithPath: String(component).trimmingCharacters(in: .whitespaces))
                if fileManager.fileExists(atPath: url.path) {
                    paths.append(url)
                }
            }
        }

        return paths
    }

    /// Find all JSONL files in Claude directories
    func findJSONLFiles() throws -> [URL] {
        let paths = getClaudePaths()
        var jsonlFiles: [URL] = []

        for basePath in paths {
            let enumerator = fileManager.enumerator(
                at: basePath,
                includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )

            while let url = enumerator?.nextObject() as? URL {
                if url.pathExtension == "jsonl" {
                    jsonlFiles.append(url)
                }
            }
        }

        return jsonlFiles
    }

    /// Load all usage entries from all JSONL files
    func loadAllEntries() async throws -> [UsageEntry] {
        let files = try findJSONLFiles()
        var allEntries: [UsageEntry] = []
        var seenIds = Set<String>()

        for file in files {
            let entries = try await parseJSONLFile(file)
            for entry in entries {
                // Deduplicate by entry ID
                if !seenIds.contains(entry.id) {
                    seenIds.insert(entry.id)
                    allEntries.append(entry)
                }
            }
        }

        // Sort by timestamp (newest first)
        return allEntries.sorted { $0.timestamp > $1.timestamp }
    }

    /// Parse a single JSONL file
    private func parseJSONLFile(_ url: URL) async throws -> [UsageEntry] {
        let data = try Data(contentsOf: url)
        guard let content = String(data: data, encoding: .utf8) else {
            return []
        }

        let lines = content.split(separator: "\n", omittingEmptySubsequences: true)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)

            // Try ISO8601 with fractional seconds
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) {
                return date
            }

            // Try without fractional seconds
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode date: \(dateString)"
            )
        }

        var entries: [UsageEntry] = []

        for line in lines {
            // Quick check for usage data before attempting full parse
            guard line.contains("\"usage\"") && line.contains("\"output_tokens\"") else {
                continue
            }

            guard let lineData = line.data(using: .utf8) else {
                continue
            }

            do {
                let entry = try decoder.decode(UsageEntry.self, from: lineData)
                // Only include entries with usage data and Claude models
                if entry.hasUsageData && entry.isClaudeModel {
                    entries.append(entry)
                }
            } catch {
                // Skip malformed entries
                continue
            }
        }

        return entries
    }

    /// Aggregate entries by day
    func aggregateByDay(_ entries: [UsageEntry], pricingService: PricingService) async -> [DailyUsage] {
        let calendar = Calendar.current

        // Group by date string
        var dayGroups: [String: [UsageEntry]] = [:]

        for entry in entries {
            let dateString = formatDate(entry.timestamp)
            dayGroups[dateString, default: []].append(entry)
        }

        // Build daily usage objects
        var dailyUsages: [DailyUsage] = []

        for (dateString, dayEntries) in dayGroups {
            var tokenCounts = TokenCounts.zero
            var totalCost = 0.0
            var modelCounts: [String: (TokenCounts, Double)] = [:]

            for entry in dayEntries {
                // Add to total tokens
                tokenCounts.add(entry)

                // Calculate cost
                let cost = await pricingService.calculateCost(entry: entry)
                totalCost += cost

                // Track per-model
                if let model = entry.message?.model {
                    var (modelTokens, modelCost) = modelCounts[model] ?? (.zero, 0)
                    modelTokens.add(entry)
                    modelCost += cost
                    modelCounts[model] = (modelTokens, modelCost)
                }
            }

            // Build model breakdowns
            let breakdowns = modelCounts.map { model, data in
                ModelBreakdown(
                    modelName: model,
                    tokenCounts: data.0,
                    cost: data.1
                )
            }.sorted { $0.cost > $1.cost }

            // Parse date from string
            let date = parseDate(dateString) ?? Date()

            dailyUsages.append(DailyUsage(
                id: dateString,
                date: date,
                tokenCounts: tokenCounts,
                totalCost: totalCost,
                modelBreakdowns: breakdowns
            ))
        }

        return dailyUsages.sorted { $0.date > $1.date }
    }

    /// Aggregate entries by month
    func aggregateByMonth(_ entries: [UsageEntry], pricingService: PricingService) async -> [MonthlyUsage] {
        let calendar = Calendar.current

        // Group by month string
        var monthGroups: [String: [UsageEntry]] = [:]

        for entry in entries {
            let components = calendar.dateComponents([.year, .month], from: entry.timestamp)
            let monthString = String(format: "%04d-%02d", components.year!, components.month!)
            monthGroups[monthString, default: []].append(entry)
        }

        // Build monthly usage objects
        var monthlyUsages: [MonthlyUsage] = []

        for (monthString, monthEntries) in monthGroups {
            var tokenCounts = TokenCounts.zero
            var totalCost = 0.0
            var modelCounts: [String: (TokenCounts, Double)] = [:]

            for entry in monthEntries {
                tokenCounts.add(entry)
                let cost = await pricingService.calculateCost(entry: entry)
                totalCost += cost

                if let model = entry.message?.model {
                    var (modelTokens, modelCost) = modelCounts[model] ?? (.zero, 0)
                    modelTokens.add(entry)
                    modelCost += cost
                    modelCounts[model] = (modelTokens, modelCost)
                }
            }

            let breakdowns = modelCounts.map { model, data in
                ModelBreakdown(modelName: model, tokenCounts: data.0, cost: data.1)
            }.sorted { $0.cost > $1.cost }

            // Parse first day of month
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM"
            let monthDate = formatter.date(from: monthString) ?? Date()

            monthlyUsages.append(MonthlyUsage(
                id: monthString,
                month: monthDate,
                tokenCounts: tokenCounts,
                totalCost: totalCost,
                modelBreakdowns: breakdowns
            ))
        }

        return monthlyUsages.sorted { $0.month > $1.month }
    }

    /// Calculate the current 5-hour session block
    func calculateCurrentBlock(_ entries: [UsageEntry], pricingService: PricingService) async -> SessionBlock? {
        let now = Date()
        let fiveHoursAgo = now.addingTimeInterval(-5 * 60 * 60)

        // Get entries from last 5 hours
        let recentEntries = entries.filter { $0.timestamp >= fiveHoursAgo }
        guard let firstEntry = recentEntries.min(by: { $0.timestamp < $1.timestamp }) else {
            return nil
        }

        let blockStart = firstEntry.timestamp
        let blockEnd = blockStart.addingTimeInterval(5 * 60 * 60)
        let isActive = now < blockEnd

        // Calculate totals for block
        var tokenCounts = TokenCounts.zero
        var totalCost = 0.0
        var models = Set<String>()

        for entry in recentEntries {
            tokenCounts.add(entry)
            totalCost += await pricingService.calculateCost(entry: entry)
            if let model = entry.message?.model {
                models.insert(model)
            }
        }

        return SessionBlock(
            id: ISO8601DateFormatter().string(from: blockStart),
            startTime: blockStart,
            endTime: blockEnd,
            isActive: isActive,
            tokenCounts: tokenCounts,
            costUSD: totalCost,
            models: Array(models)
        )
    }

    // MARK: - Date Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func parseDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }
}
