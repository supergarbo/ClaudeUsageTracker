import SwiftUI
import ServiceManagement

/// Settings window content
struct SettingsView: View {
    @AppStorage("launchAtLogin") private var launchAtLogin = true
    @AppStorage("showCostInMenuBar") private var showCostInMenuBar = true
    @AppStorage("costDecimalPlaces") private var costDecimalPlaces = 2
    @AppStorage("autoRefreshInterval") private var autoRefreshInterval = 0  // 0 = file watcher only
    @State private var loginItemError: String?

    private let refreshIntervalOptions = [
        (0, "File changes only"),
        (60, "Every minute"),
        (300, "Every 5 minutes"),
        (900, "Every 15 minutes"),
        (1800, "Every 30 minutes")
    ]

    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        updateLoginItem(enabled: newValue)
                    }

                if let error = loginItemError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("General")
            }

            Section {
                Toggle("Show Cost in Menu Bar", isOn: $showCostInMenuBar)

                Picker("Cost Decimal Places", selection: $costDecimalPlaces) {
                    Text("$1").tag(0)
                    Text("$1.2").tag(1)
                    Text("$1.23").tag(2)
                    Text("$1.234").tag(3)
                }
            } header: {
                Text("Display")
            }

            Section {
                Picker("Auto-Refresh", selection: $autoRefreshInterval) {
                    ForEach(refreshIntervalOptions, id: \.0) { interval, label in
                        Text(label).tag(interval)
                    }
                }

                Text("Data automatically refreshes when Claude logs change")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Refresh")
            }

            Section {
                LabeledContent("Data Locations") {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("~/.config/claude/projects/")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("~/.claude/projects/")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                LabeledContent("Pricing Source") {
                    Link("LiteLLM", destination: URL(string: "https://github.com/BerriAI/litellm")!)
                        .font(.caption)
                }
            } header: {
                Text("Data")
            }

            Section {
                LabeledContent("Version") {
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }

                Link("View on GitHub", destination: URL(string: "https://github.com/yourusername/ClaudeUsageTracker")!)
            } header: {
                Text("About")
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 380)
        .onAppear {
            // Sync with actual login item status
            syncLoginItemStatus()
        }
    }

    private func updateLoginItem(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginItemError = nil
        } catch {
            loginItemError = "Failed to update: \(error.localizedDescription)"
            // Revert the toggle
            launchAtLogin = !enabled
        }
    }

    private func syncLoginItemStatus() {
        let status = SMAppService.mainApp.status
        switch status {
        case .enabled:
            launchAtLogin = true
        case .notRegistered, .notFound:
            launchAtLogin = false
        case .requiresApproval:
            loginItemError = "Requires approval in System Settings > Login Items"
        @unknown default:
            break
        }
    }
}
