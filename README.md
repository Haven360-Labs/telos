# Telos

A native macOS menu bar app for day planning, time tracking, and reflection. Built with SwiftUI and SwiftData.

Telos helps knowledge workers start each day with a clear plan, focus on one task at a time, and review what got done—all without accounts, sync setup, or leaving the menu bar.

## Features

### Daily planning
- Auto-creates a plan for each calendar day with morning and end-of-day reminders
- Tasks and one level of subtasks, grouped by Eisenhower quadrant (Do first / Schedule / Delegate / Later)
- Drag-and-drop reordering within quadrants
- Rolls incomplete tasks forward; archive tasks you no longer need
- Move tasks from past days into today

### Focus & time tracking
- One active task timer at a time (countdown: 15 / 25 / 45 min, or open-ended count-up)
- Time spent recorded per task and subtask
- Menu bar shows the current task and elapsed or remaining time

### Menu bar
- Quick-add tasks and notes without opening the main window
- Recent notes at a glance
- Pause, resume, stop, or complete the active timer from the dropdown

### Reflection & habits
- Daily usage streak
- Retrospectives by day, week, month, or quarter (completed vs. incomplete, time spent, notes)
- Multi-day **Challenges** with per-day progress

### Projects, goals & future work
- **Project** hub with Kanban boards and linked day tasks
- **Goals** for longer-horizon outcomes
- **Future** inbox for tasks not yet scheduled to a day

### Notes & export
- Standalone notes in the app and from the menu bar
- CSV export of tasks and notes

### Privacy & data
- **Local-first:** all data stays on your Mac (SwiftData). No account or cloud required.
- Automatic local backups with optional iCloud mirror; manual backup and restore in Settings

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15 or later (to build from source)

## Developer guide

### Build

```bash
# Debug build
xcodebuild -scheme Telos -configuration Debug build

# Release build
xcodebuild -scheme Telos -destination 'platform=macOS' -configuration Release build
```

### Run from Xcode

```bash
open Telos.xcodeproj
# Product → Run (⌘R)
```

### Run the CLI-built app

After a Debug build, launch the `.app` from DerivedData:

```bash
open ~/Library/Developer/Xcode/DerivedData/Telos-*/Build/Products/Debug/Telos.app
```

To browse build artifacts (Debug/Release products, logs, intermediates):

```bash
open ~/Library/Developer/Xcode/DerivedData/
```

On first launch, macOS may prompt for notification permission (morning and end-of-day reminders).

## Releases

Download **`Telos-1.0.0.dmg`** (and future versions) from [GitHub Releases](https://github.com/Haven360-Labs/telos/releases).

1. Open the DMG and drag **Telos** to **Applications**
2. Open **Telos** from Applications (or Spotlight)

On first launch, macOS may prompt for **notification** permission (morning and end-of-day reminders).

### If macOS blocks Telos (“cannot check for malicious software”)

Community builds from GitHub are not notarized yet, so Gatekeeper may refuse the first launch. You can allow Telos safely as follows.

**Option A — Right-click Open (simplest)**

1. In **Finder**, open **Applications**
2. **Control-click** (or right-click) **Telos**
3. Choose **Open**
4. In the dialog, click **Open** again

You only need to do this once.

**Option B — Privacy & Security**

Use this if double-clicking shows a block message and there is no Open in the right-click menu:

1. Try to open **Telos** once (macOS will block it)
2. Open **System Settings** → **Privacy & Security**
3. Scroll to the **Security** section at the bottom
4. Next to the message about Telos being blocked, click **Open Anyway**
5. Confirm with your password or Touch ID, then click **Open** in the final prompt

If **Open Anyway** does not appear, use Option A, or ensure you attempted to launch Telos at least once before checking Settings.

An official **Mac App Store** release will not require these steps.

To build a specific tag from source:

```bash
git checkout v1.0.0   # example
```

When an official Mac App Store build ships, release tags will align with App Store version numbers where possible.

## Project structure

```
Telos/
├── TelosApp.swift              App entry, SwiftData container, environments
├── ContentView.swift           Main window, sidebar navigation, day view
├── MenuBarView.swift           Menu bar dropdown (timer, quick-add, notes)
├── StatusBarController.swift   Menu bar extra lifecycle
├── Models/                     SwiftData models (PlanDay, PlanTask, PlanNote, Project, Challenge, …)
├── Services/                   DayStore, TimerStore, StreakStore, ExportService, backup helpers
└── Views/                      Task rows, notes, retrospectives, project hub, settings, goals, …
```

Design notes and the original product spec live in [`docs/PRD-day-planning-app-ralph-tui.md`](docs/PRD-day-planning-app-ralph-tui.md).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Legal

- [License (MIT)](LICENSE)
- [Trademark guidelines](TRADEMARK.md)
- [Privacy policy](PRIVACY.md)
