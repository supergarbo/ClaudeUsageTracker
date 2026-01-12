// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClaudeUsageTracker",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "ClaudeUsageTracker",
            path: "Sources"
        )
    ]
)
