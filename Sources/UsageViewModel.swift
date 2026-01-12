import Foundation
import SwiftUI

/// Main view model for the usage tracker
@Observable
class UsageViewModel {
    // MARK: - Published State

    /// Today's aggregated usage
    var todayUsage: DailyUsage = .empty

    /// Current 5-hour billing block
    var currentBlock: SessionBlock?

    /// Daily usage for the last 14 days
    var dailyUsage: [DailyUsage] = []

    /// Monthly usage
    var monthlyUsage: [MonthlyUsage] = []

    /// Current month's usage
    var thisMonthUsage: MonthlyUsage = .empty

    /// Whether data is currently loading
    var isLoading = false

    /// Last successful data refresh time
    var lastUpdated: Date?

    /// Any error from last refresh
    var error: Error?

    // MARK: - Services

    private let dataLoader = DataLoaderService.shared
    private let pricingService = PricingService.shared
    private let fileWatcher = FileWatcherService()
    private var refreshTask: Task<Void, Never>?
    private var refreshTimer: Timer?
    private var intervalObserver: NSObjectProtocol?

    // MARK: - Initialization

    init() {
        setupFileWatcher()
        setupRefreshTimer()

        // Observe changes to refresh interval setting
        intervalObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.setupRefreshTimer()
        }

        // Initial load
        Task {
            await refresh()
        }
    }

    deinit {
        refreshTimer?.invalidate()
        if let observer = intervalObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public Methods

    /// Refresh all data
    @MainActor
    func refresh() async {
        isLoading = true
        error = nil

        do {
            // Load pricing first
            try await pricingService.loadPricing()

            // Load all usage entries
            let entries = try await dataLoader.loadAllEntries()

            // Process and aggregate
            await processEntries(entries)

            lastUpdated = Date()
        } catch {
            self.error = error
            print("Refresh error: \(error)")
        }

        isLoading = false
    }

    // MARK: - Private Methods

    private func processEntries(_ entries: [UsageEntry]) async {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Filter today's entries
        let todayEntries = entries.filter {
            calendar.isDate($0.timestamp, inSameDayAs: today)
        }

        // Calculate today's usage
        var todayTokens = TokenCounts.zero
        var todayCost = 0.0
        var todayModels: [String: (TokenCounts, Double)] = [:]

        for entry in todayEntries {
            todayTokens.add(entry)
            let cost = await pricingService.calculateCost(entry: entry)
            todayCost += cost

            if let model = entry.message?.model {
                var (t, c) = todayModels[model] ?? (.zero, 0)
                t.add(entry)
                c += cost
                todayModels[model] = (t, c)
            }
        }

        let todayBreakdowns = todayModels.map { model, data in
            ModelBreakdown(modelName: model, tokenCounts: data.0, cost: data.1)
        }.sorted { $0.cost > $1.cost }

        await MainActor.run {
            self.todayUsage = DailyUsage(
                id: formatDate(today),
                date: today,
                tokenCounts: todayTokens,
                totalCost: todayCost,
                modelBreakdowns: todayBreakdowns
            )
        }

        // Calculate current 5-hour block
        let block = await dataLoader.calculateCurrentBlock(entries, pricingService: pricingService)
        await MainActor.run {
            self.currentBlock = block
        }

        // Calculate daily aggregates (last 14 days)
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: today)!
        let recentEntries = entries.filter { $0.timestamp >= twoWeeksAgo }
        let daily = await dataLoader.aggregateByDay(recentEntries, pricingService: pricingService)
        await MainActor.run {
            self.dailyUsage = daily
        }

        // Calculate monthly aggregates
        let monthly = await dataLoader.aggregateByMonth(entries, pricingService: pricingService)
        await MainActor.run {
            self.monthlyUsage = monthly

            // Get this month
            let thisMonthString = formatMonth(today)
            self.thisMonthUsage = monthly.first { $0.id == thisMonthString } ?? .empty
        }
    }

    private func setupFileWatcher() {
        fileWatcher.onFilesChanged = { [weak self] in
            self?.refreshTask?.cancel()
            self?.refreshTask = Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
        fileWatcher.startWatching()
    }

    private func setupRefreshTimer() {
        refreshTimer?.invalidate()

        let interval = UserDefaults.standard.integer(forKey: "autoRefreshInterval")
        // Default to 60 seconds if not set (0 means unset, use default)
        let effectiveInterval = interval > 0 ? interval : 60

        refreshTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(effectiveInterval), repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func formatMonth(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }
}
