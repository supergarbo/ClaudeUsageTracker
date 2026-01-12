import SwiftUI

/// Main popover content for the menu bar
struct MenuBarView: View {
    @Bindable var viewModel: UsageViewModel
    @State private var selectedTab = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerSection

            Divider()

            // Today's usage
            TodayUsageView(usage: viewModel.todayUsage)
                .padding(.horizontal)
                .padding(.vertical, 12)

            Divider()

            // Current block
            if let block = viewModel.currentBlock {
                BlockStatusView(block: block)
                    .padding(.horizontal)
                    .padding(.vertical, 12)

                Divider()
            }

            // Chart section
            chartSection
                .padding(.horizontal)
                .padding(.vertical, 12)

            Divider()

            // This month summary
            monthSummary
                .padding(.horizontal)
                .padding(.vertical, 8)

            Divider()

            // Footer
            footerSection
        }
        .frame(width: 300)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack {
            Text("Claude Usage")
                .font(.headline)

            Spacer()

            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 16, height: 16)
            }

            Button {
                Task { await viewModel.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help("Refresh")
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LAST 7 DAYS")
                .font(.caption)
                .foregroundStyle(.secondary)

            if viewModel.dailyUsage.isEmpty {
                Text("No usage data yet")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(height: 60)
            } else {
                DailyChartView(dailyUsage: Array(viewModel.dailyUsage.prefix(7).reversed()))
                    .frame(height: 60)
            }
        }
    }

    private var monthSummary: some View {
        HStack {
            Text("This Month")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text(viewModel.thisMonthUsage.formattedCost)
                .font(.subheadline)
                .fontWeight(.medium)
                .monospacedDigit()
        }
    }

    private var footerSection: some View {
        HStack {
            if let lastUpdated = viewModel.lastUpdated {
                Text("Updated \(lastUpdated, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Button("Settings...") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
