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

Contributions are welcome. Please open an issue to discuss larger changes before submitting a pull request.

1. Fork the repository
2. Create a feature branch (`git checkout -b your-branch`)
3. Ensure the app builds: `xcodebuild -scheme Telos -configuration Debug build`
4. Open a pull request with a clear description of the change
