import SwiftUI
import ServiceManagement

@main
struct ClaudeUsageTrackerApp: App {
    @State private var viewModel = UsageViewModel()
    @AppStorage("showCostInMenuBar") private var showCostInMenuBar = true

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(viewModel: viewModel)
                .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)) { _ in
                    // Refresh after wake from sleep
                    Task {
                        try? await Task.sleep(for: .seconds(1))
                        await viewModel.refresh()
                    }
                }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chart.bar.fill")
                if showCostInMenuBar && viewModel.todayUsage.totalCost > 0 {
                    Text(viewModel.todayUsage.formattedCost)
                        .monospacedDigit()
                }
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }
}
