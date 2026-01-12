# Claude Usage Tracker

A native macOS menu bar app that displays real-time Claude Code usage and costs.

## Features

- **Real-time Updates**: Automatically refreshes when Claude Code usage changes
- **Today's Usage**: Shows current day's cost and token count
- **5-Hour Block Tracking**: Displays current billing block with time remaining
- **7-Day Chart**: Visual history of daily spending
- **Monthly Summary**: Track your monthly costs
- **Dynamic Pricing**: Fetches latest pricing from LiteLLM
- **Launch at Login**: Optionally start automatically

## Quick Start

```bash
cd ~/ClaudeUsageTracker
./build.sh
open ClaudeUsageTracker.app
```

To install permanently:
```bash
mv ClaudeUsageTracker.app /Applications/
```

## Build Requirements

- macOS 14.0 (Sonoma) or later
- Swift 5.9+ (included with Xcode Command Line Tools)

Install command line tools if needed:
```bash
xcode-select --install
```

## How It Works

The app lives in your menu bar and shows your current daily cost:

```
Menu Bar: [chart icon] $12.45
```

Click to see detailed usage:
- Today's total cost and tokens
- Current 5-hour billing block status with countdown
- 7-day usage chart
- This month's total

## Data Sources

The app reads Claude Code usage data from:
- `~/.config/claude/projects/**/*.jsonl` (primary)
- `~/.claude/projects/**/*.jsonl` (legacy)

Pricing is fetched from [LiteLLM](https://github.com/BerriAI/litellm) and cached locally at:
- `~/Library/Caches/ClaudeUsageTracker/pricing.json`

## Project Structure

```
ClaudeUsageTracker/
├── Package.swift           # Swift Package Manager config
├── build.sh               # Build script (creates .app bundle)
├── Sources/
│   ├── ClaudeUsageTrackerApp.swift
│   ├── UsageEntry.swift
│   ├── DailyUsage.swift
│   ├── SessionBlock.swift
│   ├── ModelPricing.swift
│   ├── DataLoaderService.swift
│   ├── FileWatcherService.swift
│   ├── PricingService.swift
│   ├── UsageViewModel.swift
│   ├── MenuBarView.swift
│   ├── TodayUsageView.swift
│   ├── BlockStatusView.swift
│   ├── DailyChartView.swift
│   └── SettingsView.swift
└── ClaudeUsageTracker.app  # Built application
```

## Troubleshooting

**App doesn't appear in menu bar**
- Check System Settings > Privacy & Security > Accessibility
- Try quitting and relaunching

**No data showing**
- Make sure you've used Claude Code at least once
- Check that JSONL files exist in `~/.claude/projects/` or `~/.config/claude/projects/`

**Pricing not loading**
- Check internet connection
- Cached pricing will be used if network unavailable

## License

MIT
