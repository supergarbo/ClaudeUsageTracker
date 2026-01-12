import SwiftUI
import ServiceManagement

/// Main popover content for the menu bar
struct MenuBarView: View {
    @Bindable var viewModel: UsageViewModel
    @State private var showingSettings = false

    var body: some View {
        if showingSettings {
            InlineSettingsView(showingSettings: $showingSettings)
        } else {
            mainContent
        }
    }

    private var mainContent: some View {
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

            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Settings")

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Quit")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

/// Inline settings view shown in the popover
struct InlineSettingsView: View {
    @Binding var showingSettings: Bool
    @AppStorage("showCostInMenuBar") private var showCostInMenuBar = true
    @AppStorage("costDecimalPlaces") private var costDecimalPlaces = 2
    @AppStorage("dailyBudget") private var dailyBudget = 0.0
    @AppStorage("monthlyBudget") private var monthlyBudget = 0.0
    @AppStorage("launchAtLogin") private var launchAtLogin = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Button {
                    showingSettings = false
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)

                Spacer()

                Text("Settings")
                    .font(.headline)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Display Settings
                    settingsSection("Display") {
                        Toggle("Show cost in menu bar", isOn: $showCostInMenuBar)

                        HStack {
                            Text("Decimal places")
                            Spacer()
                            Picker("", selection: $costDecimalPlaces) {
                                Text("0").tag(0)
                                Text("1").tag(1)
                                Text("2").tag(2)
                                Text("3").tag(3)
                            }
                            .labelsHidden()
                            .frame(width: 60)
                        }
                    }

                    // Budget Settings
                    settingsSection("Budget Alerts") {
                        HStack {
                            Text("Daily budget")
                            Spacer()
                            TextField("", value: $dailyBudget, format: .currency(code: "USD"))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }

                        HStack {
                            Text("Monthly budget")
                            Spacer()
                            TextField("", value: $monthlyBudget, format: .currency(code: "USD"))
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 80)
                        }

                        Text("Set to $0 to disable")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // General Settings
                    settingsSection("General") {
                        Toggle("Launch at login", isOn: $launchAtLogin)
                            .onChange(of: launchAtLogin) { _, newValue in
                                updateLoginItem(enabled: newValue)
                            }
                    }

                    // Data Info
                    settingsSection("Data") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Reads from:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("~/.claude/projects/")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Text("~/.config/claude/projects/")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 300, height: 380)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
        }
    }

    private func updateLoginItem(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update login item: \(error)")
        }
    }
}
