# Telos

Mac menu bar–first day-planning app. Native Swift (SwiftUI + SwiftData).

## Requirements

- macOS 14.0+
- Xcode 15+ (for building)

## Build & Run

```bash
# Build (quality gate for beads)
xcodebuild -scheme Telos -configuration Debug build


xcodebuild -scheme Telos -destination 'platform=macOS' -configuration Release build

open ~/Library/Developer/Xcode/DerivedData/


# Run from Xcode
open Telos.xcodeproj
# Then Product → Run (⌘R)
```

Or run the built app:

```bash
open ~/Library/Developer/Xcode/DerivedData/Telos-*/Build/Products/Debug/Telos.app
```

## Implemented (Beads)

- **US-001**: Auto-create day and morning reminder
- **US-002**: End-of-day incomplete task reminder — At or after a configurable time (default 6 PM), if today has incomplete tasks, show one notification per day when the app is opened or becomes active. No repeated reminders for the same day. — A new plan day is created each calendar day; on Mac wake, a single morning reminder can be shown to review the day.
- **US-003**: Create tasks and subtasks for the day — Add tasks to today’s plan; each task can have subtasks (one level). Tasks are persisted in SwiftData and shown in the day view.
- **US-004**: Start task and run countdown timer — One active task at a time; start a countdown (15 / 25 / 45 min) from the task row; time remaining is shown in a bar; time spent is recorded on the task when the timer finishes or is stopped.
- **US-005**: Count-up timer and time storage — From the same timer menu, choose "Count up" to run an elapsed timer (no duration); stop records time to the task. Time spent is stored per task/subtask and shown in the list (export in US-016).
- **US-006**: Roll over incomplete tasks to next day — When a new day is created (e.g. next calendar day), incomplete tasks from the previous day are moved to today. A "Rolled over from yesterday" section lists them with a "Yesterday" badge; "Today" section shows new tasks.
- **US-007**: Mark task as no longer needed / archive — Right-click a task → "Mark as no longer needed". Task (and subtasks) are archived: excluded from the active plan and not rolled forward to the next day.
- **US-008**: Eisenhower matrix — Tasks are grouped into four quadrants (Important & Urgent, Important Not Urgent, Urgent Not Important, Not Important Not Urgent). Day view shows four sections; each top-level task has a quadrant menu (Do first / Schedule / Delegate / Later). New tasks default to "Later"; ordering within quadrant by sortOrder. CSV export includes quadrant.
- **US-009**: Daily streak — Consecutive days of “use” are tracked (view plan, start/stop task, add note, quick-add, add task). Streak is shown in the main day view (e.g. “3 day streak”). Stored in UserDefaults.
- **US-010**: Retrospectives — Toolbar "Retrospective" opens a view with scope picker (Day / Week / Month / Quarter). Shows period dates, metrics (tasks completed, not completed, time spent, days used), lists "What was done" and "What wasn't", and optional notes (persisted per period in RetrospectiveEntry).
- **US-011**: Menu bar — current task and time — When a timer is active, the menu bar item shows the task label (truncated) and time (remaining or elapsed). The dropdown shows the same plus "Open Telos".
- **US-012**: Menu bar quick-add todo — In the menu bar dropdown, "Quick add task" (⌘N) reveals a title field; submit creates a task for today and persists it. Task appears in today's plan in the main window.
- **US-013**: Menu bar add note and recent notes — "Add note" in the menu bar reveals a text field; "Save note" stores a standalone note. "Recent notes" lists the 5 most recent notes (preview); tapping one opens the main app.
- **US-014**: Notes in app — Add notes from the main app (toolbar "Notes"); notes are stored in SwiftData and list/view in NotesListView; add and view/edit in sheet.
- **US-015**: Local storage only — All data is stored locally (SwiftData); no cloud or account.
- **US-016**: CSV export — Toolbar "Export…" opens a folder picker; writes `telos_tasks.csv` (plan_date, task_title, parent_title, quadrant, is_completed, time_spent_seconds, is_archived, is_rolled_over, created_at) and `telos_notes.csv` (created_at, content, plan_date). v1 scope: all data (no date filter).
- **US-017**: UI polish — Timer bar and sheets use rounded corners (10–12 pt); timer bar transitions in/out with opacity + move; list and completion toggle use withAnimation; Add task / Stop / Save use bordered button styles; Add note sheet has rounded editor background and presentationCornerRadius on all sheets.
- **US-018**: Simple flows — Add task: inline field + Enter. Start timer: one tap on play = count-up; right-click play = countdown (15/25/45 min). Add note: toolbar "Add note" or ⌘⇧N; menu bar "Add note" reveals field. No mandatory multi-step setup.

## Project structure

- `Telos/` — App source
  - `TelosApp.swift` — App entry, menu bar extra, SwiftData container
  - `ContentView.swift` — Main window, day view, task list, wake notification handling
  - `MenuBarView.swift` — Menu bar dropdown
  - `Models/PlanDay.swift` — Day model (one per calendar day); has tasks
  - `Models/PlanTask.swift` — Task/subtask model (title, completed, parent for subtasks)
  - `Models/PlanNote.swift` — Note model (content, createdAt, optional planDay)
  - `Models/RetrospectiveEntry.swift` — Optional notes per retrospective period (scope + periodStart)
  - `Views/TaskRowView.swift` — Task row with checkbox, subtasks, add-subtask
  - `Services/DayStore.swift` — Ensure today exists, morning reminder (once per day)
  - `Services/TimerStore.swift` — Active task, countdown timer, record time spent
  - `Services/ExportService.swift` — CSV export (tasks + notes) to user-chosen folder
  - `Services/StreakStore.swift` — Daily streak (record usage, compute consecutive days)
  - `Views/NotesListView.swift` — Notes list, add note, view/edit in sheet (AddNoteView, NoteDetailView)
  - `Views/RetrospectiveView.swift` — Retrospective by day/week/month/quarter; metrics, done/not done, notes

## PRD

See [docs/PRD-day-planning-app-ralph-tui.md](docs/PRD-day-planning-app-ralph-tui.md). Beads epic: `telos2-0p9`.
