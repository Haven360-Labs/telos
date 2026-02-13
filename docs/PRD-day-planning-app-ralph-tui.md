[PRD]
# PRD: Day Planning App (Telos) — Ralph TUI Version

**Version:** 1.1 (ralph-tui format, native Swift stack)  
**Source:** docs/PRD-day-planning-app.md  
**Status:** Draft

---

## 1. Introduction / Overview

Knowledge workers (software engineers, UI/UX designers, freelancers) who work primarily on a computer struggle to keep track of work across many tasks, know what to do next, see where time actually goes, and stay consistent with planning and reflection. Without a lightweight, always-available system that fits their workflow, planning becomes a chore they drop.

This PRD defines a **Mac menu bar–first day-planning app** (Telos) that: auto-creates a new day each day and reminds the user when they wake their Mac; lets them manage tasks (with subtasks), run timers (count-up or countdown), and track time per task; rolls over incomplete tasks and supports Eisenhower-style grouping; surfaces daily streaks and configurable retrospectives; and offers quick todo and notes from the menu bar, with all data in local storage and CSV export. No registration; simple to use; sleek UI with thoughtful animations.

---

## 2. Goals

- **Primary:** Users use the app every day (meaningful action: view/edit today’s plan, start/stop a task, add a note, menu bar quick-add, or open a retrospective).
- Daily streak is visible and used (habitual use).
- Retrospectives are run at least weekly by a meaningful portion of users.
- One place that surfaces “today’s plan” and “current task” to reduce cognitive load.
- Native, local-first, no signup—adoption in seconds.
- Time tracking per task plus retrospectives turn usage into insight.

---

## 3. Quality Gates

These commands must pass for every user story:

- `xcodebuild build` or `swift build` — Swift compiles and the app builds (covers typecheck).

For UI / native app stories, also include:

- Verify in the native app window (run the app in Xcode or from the command line and exercise the UI).

---

## 4. User Stories

### US-001: Auto-create day and morning reminder

**Description:** As a knowledge worker, I want a new “day” auto-created each calendar day and a gentle reminder when I wake my Mac so that I start each day with a clear plan container and a nudge to review it.

**Acceptance Criteria:**

- [ ] A new “day” is created automatically each calendar day (day is the primary container for the plan).
- [ ] When the user wakes their Mac in the morning (or first unlock/session of the day), a reminder (e.g. notification or gentle prompt) is shown to review the day.
- [ ] Reminder timing is triggerable on Mac wake (exact trigger can be sleep wake or first unlock; configurable timing is optional for this story).

---

### US-002: End-of-day incomplete task reminder

**Description:** As a user, I want one reminder per day if I have tasks still incomplete so that I can decide to finish or roll them over without being spammed.

**Acceptance Criteria:**

- [ ] At end-of-day (or a configurable time), if there are incomplete tasks for today, show a single reminder.
- [ ] Only one reminder per day for “incomplete tasks today”; no repeated notifications for the same day.

---

### US-003: Create tasks and subtasks for the day

**Description:** As a user, I want to create tasks for the day and optional subtasks under a task so that I can break work into clear, manageable pieces.

**Acceptance Criteria:**

- [ ] User can create tasks that belong to the current (or selected) day.
- [ ] User can create at least one level of subtasks under a task.
- [ ] Tasks and subtasks are persisted in local storage and displayed in the day view.

---

### US-004: Start task and run countdown timer

**Description:** As a user, I want to start a task (or subtask) and run a countdown timer so that I can time-box work and see time remaining.

**Acceptance Criteria:**

- [ ] User can start a task or a subtask; only one “active” task (or subtask) at a time.
- [ ] While a task is active, user can run a **countdown** timer.
- [ ] Time remaining is visible; time spent is recorded for the task (and subtask if supported) when the timer runs.

---

### US-005: Count-up timer and time storage

**Description:** As a user, I want to run a count-up timer and see time spent per task so that I know where my time went without setting a duration.

**Acceptance Criteria:**

- [ ] While a task is active, user can run a **count-up** timer (in addition to countdown).
- [ ] Time spent per task (and per subtask if supported) is stored in local storage.
- [ ] Time spent is visible in the UI (task detail or list) and available for export.

---

### US-006: Roll over incomplete tasks to next day

**Description:** As a user, I want incomplete tasks at end of day to roll over to the next day automatically so that I don’t lose them and can continue or drop them later.

**Acceptance Criteria:**

- [ ] When a new day is created (or at day boundary), incomplete tasks from the previous day appear in the next day’s plan (or in a clear “rolled over” section).
- [ ] Rolled-over items are identifiable (e.g. visually or by label) so the user knows they came from the previous day.

---

### US-007: Mark task as no longer needed / archive

**Description:** As a user, I want to mark a rolled-over or any task as “no longer needed” so that it is not carried forward and my list stays relevant.

**Acceptance Criteria:**

- [ ] User can mark a task (including rolled-over) as no longer needed or archived.
- [ ] Marked tasks are not carried forward to subsequent days (or are moved to an archive view and excluded from the active plan).

---

### US-008: Eisenhower matrix (importance / urgency)

**Description:** As a user, I want the day’s plan grouped into four quadrants (Important & Urgent, Important Not Urgent, Urgent Not Important, Not Important Not Urgent) so that I can prioritize by importance and urgency.

**Acceptance Criteria:**

- [ ] User can assign each task to one of four quadrants (e.g. drag-and-drop or picker).
- [ ] The main day view displays tasks in these four groups with clear visual separation.
- [ ] Ordering within a quadrant can be manual or by priority (implementation choice).

---

### US-009: Daily streak

**Description:** As a user, I want to see a daily streak (consecutive days I’ve used the app) so that I’m motivated to stay consistent.

**Acceptance Criteria:**

- [ ] Daily streak is computed and displayed (e.g. “N days” or similar).
- [ ] “Used” is defined consistently (e.g. at least one meaningful action: view/edit plan, start/stop task, add note, quick-add, or open retrospective).
- [ ] Streak is visible in the main app (and optionally in menu bar or retrospectives).

---

### US-010: Retrospectives (day / week / month / quarter)

**Description:** As a user, I want to run a retrospective for a day, week, month, or quarter so that I can reflect on what was done and what to improve.

**Acceptance Criteria:**

- [ ] User can choose retrospective scope: day, week, month, or quarter (e.g. configurable default).
- [ ] Retrospective view shows relevant data for the period (e.g. tasks completed, time spent, streak).
- [ ] At minimum: what was done, what wasn’t, optional notes; exact metrics can be refined in a follow-up story.

---

### US-011: Menu bar — current task and time

**Description:** As a user, I want the menu bar to show my current task and time remaining (countdown) or time spent (count-up) so that I can stay aware without opening the main window.

**Acceptance Criteria:**

- [ ] When a task is active, the menu bar shows the current task label.
- [ ] Menu bar shows either time remaining (countdown) or time spent (count-up) depending on active timer mode.
- [ ] Display is compact and always visible while a task is active.

---

### US-012: Menu bar quick-add todo

**Description:** As a user, I want to quick-add a todo from the menu bar so that I can capture a task for today without opening the main app.

**Acceptance Criteria:**

- [ ] Menu bar has an action to add a todo (e.g. “Quick add” or “Add task”).
- [ ] Minimal input (e.g. title only) creates a task for today.
- [ ] Task appears in today’s plan and is persisted.

---

### US-013: Menu bar add note and recent notes

**Description:** As a user, I want to add a note from the menu bar and optionally view recent notes so that I can capture thoughts quickly.

**Acceptance Criteria:**

- [ ] From menu bar, user can add a note (minimal flow; note stored and linked to day or standalone per product decision).
- [ ] User can optionally view recent notes from the menu bar (e.g. list or dropdown).

---

### US-014: Notes in app — add, store, list/view

**Description:** As a user, I want to add notes from the main app and have them stored and viewable so that I can keep context and reflections in one place.

**Acceptance Criteria:**

- [ ] User can add notes from the main app (and optionally tie to a day or keep standalone).
- [ ] Notes are stored in local storage and retrievable.
- [ ] User can list and view notes in the app; notes are included in export if applicable.

---

### US-015: Local storage only (no cloud)

**Description:** As a user, I want all data stored only on my device with no account or cloud so that I have privacy and zero signup friction.

**Acceptance Criteria:**

- [ ] No user registration or cloud sync; all app data is stored locally on the device.
- [ ] No network calls for storing or loading plan/task/note data (except optional future export path).

---

### US-016: CSV export

**Description:** As a user, I want to export my data to CSV so that I can backup or analyze it outside the app.

**Acceptance Criteria:**

- [ ] User can trigger an export to CSV from the app (e.g. settings or a dedicated export action).
- [ ] Export includes at least tasks and time data; notes included if applicable.
- [ ] Export scope (e.g. date range) can be fixed for v1 or configurable; documented in UI or help.

---

### US-017: UI polish — sleek and animated

**Description:** As a user, I want the UI to feel modern and responsive with thoughtful animations so that the app is pleasant to use daily.

**Acceptance Criteria:**

- [ ] UI uses a consistent, sleek visual style (not cluttered).
- [ ] Transitions and micro-interactions (e.g. list updates, timer start/stop, modal open/close) are smooth and intentional.
- [ ] Quality bar: feels modern and responsive.

---

### US-018: Simple flows — minimal steps

**Description:** As a user, I want to add a task, start a timer, and add a note with minimal steps so that core actions stay fast.

**Acceptance Criteria:**

- [ ] Adding a task requires minimal steps (no unnecessary modals or configuration for the default case).
- [ ] Starting a timer is one or two actions from the task.
- [ ] Adding a note is minimal steps from menu bar or main app.
- [ ] No mandatory multi-step setup for core flows beyond optional preferences.

---

## 5. Functional Requirements

- FR-1: The system must create one “day” per calendar day and use it as the primary plan container.
- FR-2: The system must show a morning reminder on Mac wake (or first session) to review the day.
- FR-3: The system must show at most one end-of-day reminder for incomplete tasks per day.
- FR-4: The system must allow creating tasks for a day and subtasks under a task (at least one level).
- FR-5: The system must allow only one active task (or subtask) at a time when time-tracking.
- FR-6: The system must support countdown and count-up timers and persist time spent per task/subtask.
- FR-7: The system must roll over incomplete tasks to the next day and allow marking tasks as no longer needed.
- FR-8: The system must group tasks into four Eisenhower quadrants and display them in the day view.
- FR-9: The system must compute and display a daily streak based on a defined “used” rule.
- FR-10: The system must support retrospectives for day, week, month, and quarter with relevant period data.
- FR-11: The menu bar must show current task and time (remaining or spent) when a task is active.
- FR-12: The menu bar must support quick-add todo and add note; optional recent notes.
- FR-13: Notes must be storable and viewable in-app and from menu bar where applicable.
- FR-14: All data must be stored locally; no cloud or account.
- FR-15: The system must support CSV export for tasks (and time) and notes.
- FR-16: The UI must be sleek, animated, and simple for core flows.

---

## 6. Non-Goals (Out of Scope)

- User registration or accounts; no sign-up, login, or cloud identity.
- Cloud sync or backup; data lives only on device; CSV export is the backup path.
- Mobile app; Mac (desktop/menu bar) only.
- Integrations (Calendar, Slack, Notion, etc.).
- Collaboration or sharing; single-user only.
- Complex onboarding; no multi-step tutorials beyond optional preferences.
- AI-driven suggestions; no auto-scheduling or AI-generated plans; user defines tasks and quadrants.

---

## 7. Technical Considerations

- **Stack:** Native Swift (SwiftUI/AppKit); Telos app.
- **Storage:** Local only (e.g. UserDefaults, SwiftData, or SQLite via Foundation); no backend.
- **Platform:** Mac menu bar and main window; reminder triggers depend on Mac wake/unlock (native system APIs).
- **Export:** CSV generation in Swift; file save via NSSavePanel or equivalent native APIs.
- Implementation order: core day + tasks + timer first, then menu bar, then streaks/retro, then polish and export.

---

## 8. Success Metrics

- **Primary:** Users use the app every day (at least one meaningful action per day).
- **Target (to set at launch):** e.g. X% of users who complete onboarding use the app on 5+ days in their first 2 weeks.
- Daily streak is visible and used.
- Retrospectives run at least weekly by a meaningful portion of users.

---

## 9. Open Questions

- Exact “Mac wake” detection (sleep wake vs first unlock) and reminder timing (fixed window vs user setting).
- Definition of “used” for daily streak and success metric (any action vs task completed).
- Retrospective default period and exact data shown per period (day/week/month/quarter).
- CSV export schema (tasks, time logs, notes, date range) and where export lives in UI.
- Whether notes are day-scoped only or can be standalone and how they appear in menu bar.
- Priority order for implementation (e.g. US-001 through US-007 first, then menu bar, then streaks/retro).

---

## 10. Document History

| Version | Date       | Changes                                      |
|---------|------------|----------------------------------------------|
| 1.0     | Feb 2025   | Initial PRD (docs/PRD-day-planning-app.md). |
| 1.0-tui | Feb 2025   | Ralph TUI format: Quality Gates, user stories, [PRD] markers. |
| 1.1     | Feb 2025   | Stack changed from Tauri + React/TypeScript to native Swift. |
[/PRD]
