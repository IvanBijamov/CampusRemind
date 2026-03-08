# CampusRemind

Automatically sync your university assignments from any iCal-compatible LMS calendar (including Moodle) to Apple Reminders. One list per course, with due dates and AI-summarized descriptions. Never miss an assignment again.

> **This app is not affiliated with or endorsed by the Moodle project.**

---

## Features

- **Automatic Sync** — Fetches your course calendar via iCal export and creates organized Apple Reminders
- **One List Per Course** — Each course gets its own Reminders list, auto-named in `DEPT NUMBER` format (e.g., "HIS 213")
- **Smart Deduplication** — Existing reminders (including completed ones) are never re-created
- **On-Device AI Summarization** — Optionally shorten verbose assignment descriptions using Apple Foundation Models — all processing stays on your device
- **Background Sync** — iOS uses `BGProcessingTask`; macOS uses `launchd` for scheduled daily syncs
- **Course Filtering** — Exclude courses by substring match (e.g., "PHY 108", "Lab Section")
- **Privacy-First** — No accounts, no analytics, no tracking, no cloud. All data stays on your device
- **Cross-Platform** — Shared core library powers both a macOS CLI and a native iOS app

---

## Table of Contents

- [Requirements](#requirements)
- [Architecture](#architecture)
- [Getting Started](#getting-started)
  - [iOS App](#ios-app)
  - [macOS CLI](#macos-cli)
- [CLI Usage](#cli-usage)
  - [configure](#configure)
  - [sync](#sync)
  - [exclude](#exclude)
  - [install-schedule](#install-schedule)
  - [uninstall-schedule](#uninstall-schedule)
- [iOS App Guide](#ios-app-guide)
- [How to Get Your iCal URL](#how-to-get-your-ical-url)
- [Configuration](#configuration)
- [AI Summarization](#ai-summarization)
- [Privacy](#privacy)
- [License](#license)

---

## Requirements

| Platform | Minimum Version |
|----------|----------------|
| macOS    | 26.0+          |
| iOS      | 18.0+          |

- **Swift** 6.2+ (language mode v5)
- **Xcode** 16.2+
- Apple Reminders access (prompted on first run)
- A calendar export URL from your institution's LMS

---

## Architecture

The project is split into three targets:

```
CampusRemind/
├── Package.swift
├── Sources/
│   ├── CampusRemindCore/          # Shared library (SPM target)
│   │   ├── Config/
│   │   │   ├── AppConfig.swift        # JSON config persistence
│   │   │   └── KeychainHelper.swift   # Secure credential storage
│   │   ├── Moodle/
│   │   │   └── ICalParser.swift       # RFC 5545 iCal parser
│   │   ├── Network/
│   │   │   └── NetworkMonitor.swift   # Connectivity check with timeout
│   │   ├── Reminders/
│   │   │   └── RemindersManager.swift # EventKit reminder creation (actor)
│   │   ├── AI/
│   │   │   ├── DescriptionSummarizer.swift  # Summarization logic (actor)
│   │   │   └── OnDeviceModelClient.swift    # Apple FoundationModels wrapper
│   │   └── Sync/
│   │       └── SyncService.swift      # Core sync orchestration
│   └── CampusRemind/              # macOS CLI executable
│       ├── Entry.swift                # ArgumentParser entry point
│       ├── Commands/
│       │   ├── SyncCommand.swift
│       │   ├── ConfigureCommand.swift
│       │   ├── ExcludeCommand.swift
│       │   ├── InstallScheduleCommand.swift
│       │   └── UninstallScheduleCommand.swift
│       └── Schedule/
│           └── LaunchAgentManager.swift  # launchd agent management
├── CampusRemindApp/               # iOS app (Xcode project)
│   ├── CampusRemindApp.xcodeproj/
│   ├── CampusRemindApp/
│   │   ├── CampusRemindApp.swift      # @main App entry point
│   │   ├── Info.plist
│   │   ├── Assets.xcassets/
│   │   ├── Background/
│   │   │   └── BackgroundTaskManager.swift  # BGProcessingTask handler
│   │   ├── Views/
│   │   │   ├── ContentView.swift      # Root view (setup vs. main tabs)
│   │   │   ├── SetupView.swift        # Initial configuration form
│   │   │   ├── SyncStatusView.swift   # Sync status + manual trigger
│   │   │   └── SettingsView.swift     # Preferences + exclusions
│   │   └── ViewModels/
│   │       ├── SetupViewModel.swift
│   │       ├── SyncViewModel.swift
│   │       └── SettingsViewModel.swift
│   └── PrivacyPolicy.md
└── LICENSE
```

**CampusRemindCore** is the shared engine — both the CLI and iOS app depend on it without modification. Platform-specific scheduling is handled separately: `launchd` on macOS, `BGProcessingTask` on iOS.

---

## Getting Started

### iOS App

1. Open `CampusRemindApp/CampusRemindApp.xcodeproj` in Xcode
2. Select your development team under Signing & Capabilities
3. Build and run on a device or simulator
4. The app will walk you through setup — paste your iCal URL and grant Reminders access

### macOS CLI

**Build from source:**

```bash
swift build -c release
```

The compiled binary will be at `.build/release/CampusRemind`.

**Optional — install globally:**

```bash
cp .build/release/CampusRemind /usr/local/bin/campusremind
```

**Run initial setup:**

```bash
campusremind configure
```

---

## CLI Usage

```
USAGE: campusremind <subcommand>

SUBCOMMANDS:
  sync (default)        Sync Moodle assignments to Apple Reminders
  configure             Configure Moodle iCal URL and settings
  exclude               Manage excluded courses (by substring match)
  install-schedule      Install a daily launchd agent to sync automatically
  uninstall-schedule    Remove the daily sync launchd agent
```

### configure

Interactive setup wizard that prompts for your Moodle URL, iCal export URL, and AI summarization preference. Saves configuration to `~/.campusremind/config.json` and requests Reminders access.

```bash
campusremind configure
```

### sync

Fetches your iCal feed, parses assignment events, and creates Apple Reminders organized by course.

```bash
# Basic sync
campusremind sync

# Preview without creating anything
campusremind sync --dry-run

# Detailed output
campusremind sync --verbose

# Skip network connectivity check
campusremind sync --skip-network-check

# Custom network timeout (default: 300s)
campusremind sync --network-timeout 60

# Disable AI summarization for this run
campusremind sync --no-summarize
```

### exclude

Manage which courses are skipped during sync. Courses whose names contain any exclusion substring (case-insensitive) are filtered out.

```bash
# List current exclusions
campusremind exclude

# Add exclusions
campusremind exclude "PHY 108" "Lab Section"

# Remove a specific exclusion
campusremind exclude --remove "PHY 108"

# Clear all exclusions
campusremind exclude --clear
```

### install-schedule

Installs a `launchd` agent that runs `campusremind sync` daily at a specified hour.

```bash
# Install daily sync at 8:00 AM (default)
campusremind install-schedule

# Sync at 6:00 PM instead
campusremind install-schedule --hour 18
```

The agent is installed at `~/Library/LaunchAgents/com.campusremind.sync.plist` with logs written to `~/.campusremind/sync.log`.

### uninstall-schedule

Removes the launchd agent and its plist file.

```bash
campusremind uninstall-schedule
```

---

## iOS App Guide

The iOS app has two tabs after initial setup:

### Sync Tab
- Shows the **last sync time** (relative, e.g., "2 hours ago") and **result summary**
- **Sync Now** button triggers a manual sync with a progress spinner
- **Pull-to-refresh** also triggers a sync
- Background sync runs automatically when the app enters the background via `BGProcessingTask`

### Settings Tab
- **AI Summarization** toggle — enable or disable on-device description shortening
- **Excluded Courses** — add, remove, or swipe-to-delete course name filters
- **Reconfigure** — deletes your configuration and returns to the setup screen (with confirmation)

---

## How to Get Your iCal URL

1. Log into your institution's Moodle in a web browser
2. Navigate to **Calendar** (or Dashboard)
3. Click **Export calendar** at the bottom of the page
4. Select **All courses** and **Events from courses**
5. Click **Get calendar URL** and copy the URL

This URL is a static link to your personal calendar feed. It does not expire but is unique to your account.

---

## Configuration

Configuration is stored as a JSON file:

| Platform | Path |
|----------|------|
| macOS    | `~/.campusremind/config.json` |
| iOS      | `<App Documents>/CampusRemind/config.json` |

**Fields:**

| Key | Type | Description |
|-----|------|-------------|
| `moodleBaseURL` | String | Your Moodle instance URL |
| `icalURL` | String | iCal calendar export URL |
| `excludedCourses` | [String]? | Course name substrings to skip |
| `enableSummarization` | Bool? | Enable AI description summarization |
| `lastSyncDate` | Date? | Timestamp of most recent sync |
| `lastSyncResult` | String? | Human-readable sync result |

---

## AI Summarization

When enabled, verbose assignment descriptions are shortened using Apple's on-device Foundation Models (Apple Intelligence). The summarizer:

- Passes through short descriptions (< 100 characters) unchanged
- Extracts key information: what to do, format/length requirements, and key topics
- Removes: grading rubrics, late policies, boilerplate, submission instructions
- Produces 2-4 concise sentences in plain text
- Falls back to the original description if summarization fails

**Requirements:** macOS 26+ or iOS 26+ with Apple Intelligence support. On unsupported devices, summarization is silently skipped.

---

## Sync Behavior

Each sync performs the following steps:

1. **Wait for network** — checks connectivity with a configurable timeout
2. **Fetch iCal feed** — downloads and parses the `.ics` file from your URL
3. **Clean course names** — extracts `DEPT NUMBER` format from complex course codes (e.g., `HIS-213-1/CRE-213-1-202610` → `HIS 213`)
4. **Merge duplicates** — consolidates cross-listed courses after name cleaning
5. **Filter exclusions** — removes courses matching any exclusion substring
6. **Filter events** — skips Attendance events automatically
7. **Check for existing reminders** — matches by title + due date (minute precision), including completed reminders
8. **Summarize descriptions** — if AI is enabled, shorten long descriptions
9. **Create reminders** — one Reminders list per course, one reminder per assignment with title, notes, and due date

Sync supports graceful cancellation at any point (important for iOS background task time limits).

---

## Privacy

CampusRemind is designed with privacy as a core principle:

- **No account creation** — works with a user-provided iCal URL
- **No data collection** — no analytics, no tracking, no advertising
- **Local storage only** — all configuration stored on-device, no cloud sync
- **Single network request** — fetches your iCal feed from your institution's server; no data sent to any third party
- **On-device AI** — summarization uses Apple Foundation Models locally; no data leaves your device
- **No third-party SDKs** — zero external dependencies beyond Apple frameworks and Swift ArgumentParser

See [Privacy Policy](CampusRemindApp/PrivacyPolicy.md) for the full policy.

---

## License

[MIT](LICENSE) — Ivan Bijamov, 2026
