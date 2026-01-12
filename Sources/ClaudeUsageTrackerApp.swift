import SwiftUI
import ServiceManagement

@main
struct ClaudeUsageTrackerApp: App {
    @State private var viewModel = UsageViewModel()

    var body: some Scene {
        // Menu bar with popover
        MenuBarExtra {
            MenuBarView(viewModel: viewModel)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chart.bar.fill")
                if viewModel.todayUsage.totalCost > 0 {
                    Text(viewModel.todayUsage.formattedCost)
                        .monospacedDigit()
                }
            }
        }
        .menuBarExtraStyle(.window)

        // Settings window
        Settings {
            SettingsView()
        }
    }
}
