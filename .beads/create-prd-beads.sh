#!/usr/bin/env bash
# Create beads from docs/PRD-day-planning-app-ralph-tui.md (ralph-tui-create-beads skill)
# Quality gates: native Swift — xcodebuild/swift build; verify in native app
set -e
cd "$(dirname "$0")/.."
BEADS_DIR=".beads"
DESC_DIR="$BEADS_DIR/prd-desc"
mkdir -p "$DESC_DIR"

# Quality gates text (append to every bead) — native Swift stack
QG="
- [ ] xcodebuild build or swift build passes (Swift compiles and app builds)"
QG_UI="
- [ ] Verify in the native app window (run the app in Xcode or from the command line and exercise the UI)"

# --- Epic ---
cat > "$DESC_DIR/epic.txt" << 'DESCEOF'
Mac menu bar–first day-planning app (Telos): auto-create day and morning reminder; manage tasks and subtasks; count-up and countdown timers with time tracking; roll over incomplete tasks; Eisenhower matrix; daily streaks and retrospectives; menu bar quick-add and notes; local storage only; CSV export; sleek UI.

Source: docs/PRD-day-planning-app-ralph-tui.md
DESCEOF

EPIC_ID=$(bd create --type=epic \
  --title="Day Planning App (Telos)" \
  --body-file="$DESC_DIR/epic.txt" \
  --external-ref="prd:./docs/PRD-day-planning-app-ralph-tui.md" \
  --silent)
echo "Epic: $EPIC_ID"

# --- US-001 ---
cat > "$DESC_DIR/us001.txt" << 'DESCEOF'
As a knowledge worker, I want a new "day" auto-created each calendar day and a gentle reminder when I wake my Mac so that I start each day with a clear plan container and a nudge to review it.

## Acceptance Criteria
- [ ] A new "day" is created automatically each calendar day (day is the primary container for the plan).
- [ ] When the user wakes their Mac in the morning (or first unlock/session of the day), a reminder (e.g. notification or gentle prompt) is shown to review the day.
- [ ] Reminder timing is triggerable on Mac wake (exact trigger can be sleep wake or first unlock; configurable timing is optional for this story).
DESCEOF
echo -n "$QG" >> "$DESC_DIR/us001.txt"
echo -n "$QG_UI" >> "$DESC_DIR/us001.txt"

US001=$(bd create --parent="$EPIC_ID" --title="US-001: Auto-create day and morning reminder" \
  --body-file="$DESC_DIR/us001.txt" --priority=0 --silent)
echo "US-001: $US001"

# --- US-002 ---
cat > "$DESC_DIR/us002.txt" << 'DESCEOF'
As a user, I want one reminder per day if I have tasks still incomplete so that I can decide to finish or roll them over without being spammed.

## Acceptance Criteria
- [ ] At end-of-day (or a configurable time), if there are incomplete tasks for today, show a single reminder.
- [ ] Only one reminder per day for "incomplete tasks today"; no repeated notifications for the same day.
DESCEOF
echo -n "$QG" >> "$DESC_DIR/us002.txt"
echo -n "$QG_UI" >> "$DESC_DIR/us002.txt"

US002=$(bd create --parent="$EPIC_ID" --title="US-002: End-of-day incomplete task reminder" \
  --body-file="$DESC_DIR/us002.txt" --priority=2 --silent)
echo "US-002: $US002"

# --- US-003 ---
cat > "$DESC_DIR/us003.txt" << 'DESCEOF'
As a user, I want to create tasks for the day and optional subtasks under a task so that I can break work into clear, manageable pieces.

## Acceptance Criteria
- [ ] User can create tasks that belong to the current (or selected) day.
- [ ] User can create at least one level of subtasks under a task.
- [ ] Tasks and subtasks are persisted in local storage and displayed in the day view.
DESCEOF
echo -n "$QG" >> "$DESC_DIR/us003.txt"
echo -n "$QG_UI" >> "$DESC_DIR/us003.txt"

US003=$(bd create --parent="$EPIC_ID" --title="US-003: Create tasks and subtasks for the day" \
  --body-file="$DESC_DIR/us003.txt" --priority=1 --silent)
echo "US-003: $US003"

# --- US-004 ---
cat > "$DESC_DIR/us004.txt" << 'DESCEOF'
As a user, I want to start a task (or subtask) and run a countdown timer so that I can time-box work and see time remaining.

## Acceptance Criteria
- [ ] User can start a task or a subtask; only one "active" task (or subtask) at a time.
- [ ] While a task is active, user can run a countdown timer.
- [ ] Time remaining is visible; time spent is recorded for the task (and subtask if supported) when the timer runs.
DESCEOF
echo -n "$QG" >> "$DESC_DIR/us004.txt"
echo -n "$QG_UI" >> "$DESC_DIR/us004.txt"

US004=$(bd create --parent="$EPIC_ID" --title="US-004: Start task and run countdown timer" \
  --body-file="$DESC_DIR/us004.txt" --priority=1 --silent)
echo "US-004: $US004"

# --- US-005 ---
cat > "$DESC_DIR/us005.txt" << 'DESCEOF'
As a user, I want to run a count-up timer and see time spent per task so that I know where my time went without setting a duration.

## Acceptance Criteria
- [ ] While a task is active, user can run a count-up timer (in addition to countdown).
- [ ] Time spent per task (and per subtask if supported) is stored in local storage.
- [ ] Time spent is visible in the UI (task detail or list) and available for export.
DESCEOF
echo -n "$QG" >> "$DESC_DIR/us005.txt"
echo -n "$QG_UI" >> "$DESC_DIR/us005.txt"

US005=$(bd create --parent="$EPIC_ID" --title="US-005: Count-up timer and time storage" \
  --body-file="$DESC_DIR/us005.txt" --priority=1 --silent)
echo "US-005: $US005"

# --- US-006 ---
cat > "$DESC_DIR/us006.txt" << 'DESCEOF'
As a user, I want incomplete tasks at end of day to roll over to the next day automatically so that I don't lose them and can continue or drop them later.

## Acceptance Criteria
- [ ] When a new day is created (or at day boundary), incomplete tasks from the previous day appear in the next day's plan (or in a clear "rolled over" section).
- [ ] Rolled-over items are identifiable (e.g. visually or by label) so the user knows they came from the previous day.
DESCEOF
echo -n "$QG" >> "$DESC_DIR/us006.txt"
echo -n "$QG_UI" >> "$DESC_DIR/us006.txt"

US006=$(bd create --parent="$EPIC_ID" --title="US-006: Roll over incomplete tasks to next day" \
  --body-file="$DESC_DIR/us006.txt" --priority=2 --silent)
echo "US-006: $US006"

# --- US-007 ---
cat > "$DESC_DIR/us007.txt" << 'DESCEOF'
As a user, I want to mark a rolled-over or any task as "no longer needed" so that it is not carried forward and my list stays relevant.

## Acceptance Criteria
- [ ] User can mark a task (including rolled-over) as no longer needed or archived.
- [ ] Marked tasks are not carried forward to subsequent days (or are moved to an archive view and excluded from the active plan).
DESCEOF
echo -n "$QG" >> "$DESC_DIR/us007.txt"
echo -n "$QG_UI" >> "$DESC_DIR/us007.txt"

US007=$(bd create --parent="$EPIC_ID" --title="US-007: Mark task as no longer needed / archive" \
  --body-file="$DESC_DIR/us007.txt" --priority=2 --silent)
echo "US-007: $US007"

# --- US-008 ---
cat > "$DESC_DIR/us008.txt" << 'DESCEOF'
As a user, I want the day's plan grouped into four quadrants (Important & Urgent, Important Not Urgent, Urgent Not Important, Not Important Not Urgent) so that I can prioritize by importance and urgency.

## Acceptance Criteria
- [ ] User can assign each task to one of four quadrants (e.g. drag-and-drop or picker).
- [ ] The main day view displays tasks in these four groups with clear visual separation.
- [ ] Ordering within a quadrant can be manual or by priority (implementation choice).
DESCEOF
echo -n "$QG" >> "$DESC_DIR/us008.txt"
echo -n "$QG_UI" >> "$DESC_DIR/us008.txt"

US008=$(bd create --parent="$EPIC_ID" --title="US-008: Eisenhower matrix (importance / urgency)" \
  --body-file="$DESC_DIR/us008.txt" --priority=2 --silent)
echo "US-008: $US008"

# --- US-009 ---
cat > "$DESC_DIR/us009.txt" << 'DESCEOF'
As a user, I want to see a daily streak (consecutive days I've used the app) so that I'm motivated to stay consistent.

## Acceptance Criteria
- [ ] Daily streak is computed and displayed (e.g. "N days" or similar).
- [ ] "Used" is defined consistently (e.g. at least one meaningful action: view/edit plan, start/stop task, add note, quick-add, or open retrospective).
- [ ] Streak is visible in the main app (and optionally in menu bar or retrospectives).
DESCEOF
echo -n "$QG" >> "$DESC_DIR/us009.txt"
echo -n "$QG_UI" >> "$DESC_DIR/us009.txt"

US009=$(bd create --parent="$EPIC_ID" --title="US-009: Daily streak" \
  --body-file="$DESC_DIR/us009.txt" --priority=2 --silent)
echo "US-009: $US009"

# --- US-010 ---
cat > "$DESC_DIR/us010.txt" << 'DESCEOF'
As a user, I want to run a retrospective for a day, week, month, or quarter so that I can reflect on what was done and what to improve.

## Acceptance Criteria
- [ ] User can choose retrospective scope: day, week, month, or quarter (e.g. configurable default).
- [ ] Retrospective view shows relevant data for the period (e.g. tasks completed, time spent, streak).
- [ ] At minimum: what was done, what wasn't, optional notes; exact metrics can be refined in a follow-up story.
DESCEOF
echo -n "$QG" >> "$DESC_DIR/us010.txt"
echo -n "$QG_UI" >> "$DESC_DIR/us010.txt"

US010=$(bd create --parent="$EPIC_ID" --title="US-010: Retrospectives (day / week / month / quarter)" \
  --body-file="$DESC_DIR/us010.txt" --priority=2 --silent)
echo "US-010: $US010"

# --- US-011 ---
cat > "$DESC_DIR/us011.txt" << 'DESCEOF'
As a user, I want the menu bar to show my current task and time remaining (countdown) or time spent (count-up) so that I can stay aware without opening the main window.

## Acceptance Criteria
- [ ] When a task is active, the menu bar shows the current task label.
- [ ] Menu bar shows either time remaining (countdown) or time spent (count-up) depending on active timer mode.
- [ ] Display is compact and always visible while a task is active.
DESCEOF
echo -n "$QG" >> "$DESC_DIR/us011.txt"
echo -n "$QG_UI" >> "$DESC_DIR/us011.txt"

US011=$(bd create --parent="$EPIC_ID" --title="US-011: Menu bar — current task and time" \
  --body-file="$DESC_DIR/us011.txt" --priority=2 --silent)
echo "US-011: $US011"

# --- US-012 ---
cat > "$DESC_DIR/us012.txt" << 'DESCEOF'
As a user, I want to quick-add a todo from the menu bar so that I can capture a task for today without opening the main app.

## Acceptance Criteria
- [ ] Menu bar has an action to add a todo (e.g. "Quick add" or "Add task").
- [ ] Minimal input (e.g. title only) creates a task for today.
- [ ] Task appears in today's plan and is persisted.
DESCEOF
echo -n "$QG" >> "$DESC_DIR/us012.txt"
echo -n "$QG_UI" >> "$DESC_DIR/us012.txt"

US012=$(bd create --parent="$EPIC_ID" --title="US-012: Menu bar quick-add todo" \
  --body-file="$DESC_DIR/us012.txt" --priority=2 --silent)
echo "US-012: $US012"

# --- US-013 ---
cat > "$DESC_DIR/us013.txt" << 'DESCEOF'
As a user, I want to add a note from the menu bar and optionally view recent notes so that I can capture thoughts quickly.

## Acceptance Criteria
- [ ] From menu bar, user can add a note (minimal flow; note stored and linked to day or standalone per product decision).
- [ ] User can optionally view recent notes from the menu bar (e.g. list or dropdown).
DESCEOF
echo -n "$QG" >> "$DESC_DIR/us013.txt"
echo -n "$QG_UI" >> "$DESC_DIR/us013.txt"

US013=$(bd create --parent="$EPIC_ID" --title="US-013: Menu bar add note and recent notes" \
  --body-file="$DESC_DIR/us013.txt" --priority=2 --silent)
echo "US-013: $US013"

# --- US-014 ---
cat > "$DESC_DIR/us014.txt" << 'DESCEOF'
As a user, I want to add notes from the main app and have them stored and viewable so that I can keep context and reflections in one place.

## Acceptance Criteria
- [ ] User can add notes from the main app (and optionally tie to a day or keep standalone).
- [ ] Notes are stored in local storage and retrievable.
- [ ] User can list and view notes in the app; notes are included in export if applicable.
DESCEOF
echo -n "$QG" >> "$DESC_DIR/us014.txt"
echo -n "$QG_UI" >> "$DESC_DIR/us014.txt"

US014=$(bd create --parent="$EPIC_ID" --title="US-014: Notes in app — add, store, list/view" \
  --body-file="$DESC_DIR/us014.txt" --priority=2 --silent)
echo "US-014: $US014"

# --- US-015 ---
cat > "$DESC_DIR/us015.txt" << 'DESCEOF'
As a user, I want all data stored only on my device with no account or cloud so that I have privacy and zero signup friction.

## Acceptance Criteria
- [ ] No user registration or cloud sync; all app data is stored locally on the device.
- [ ] No network calls for storing or loading plan/task/note data (except optional future export path).
DESCEOF
echo -n "$QG" >> "$DESC_DIR/us015.txt"
echo -n "$QG_UI" >> "$DESC_DIR/us015.txt"

US015=$(bd create --parent="$EPIC_ID" --title="US-015: Local storage only (no cloud)" \
  --body-file="$DESC_DIR/us015.txt" --priority=0 --silent)
echo "US-015: $US015"

# --- US-016 ---
cat > "$DESC_DIR/us016.txt" << 'DESCEOF'
As a user, I want to export my data to CSV so that I can backup or analyze it outside the app.

## Acceptance Criteria
- [ ] User can trigger an export to CSV from the app (e.g. settings or a dedicated export action).
- [ ] Export includes at least tasks and time data; notes included if applicable.
- [ ] Export scope (e.g. date range) can be fixed for v1 or configurable; documented in UI or help.
DESCEOF
echo -n "$QG" >> "$DESC_DIR/us016.txt"
echo -n "$QG_UI" >> "$DESC_DIR/us016.txt"

US016=$(bd create --parent="$EPIC_ID" --title="US-016: CSV export" \
  --body-file="$DESC_DIR/us016.txt" --priority=3 --silent)
echo "US-016: $US016"

# --- US-017 ---
cat > "$DESC_DIR/us017.txt" << 'DESCEOF'
As a user, I want the UI to feel modern and responsive with thoughtful animations so that the app is pleasant to use daily.

## Acceptance Criteria
- [ ] UI uses a consistent, sleek visual style (not cluttered).
- [ ] Transitions and micro-interactions (e.g. list updates, timer start/stop, modal open/close) are smooth and intentional.
- [ ] Quality bar: feels modern and responsive.
DESCEOF
echo -n "$QG" >> "$DESC_DIR/us017.txt"
echo -n "$QG_UI" >> "$DESC_DIR/us017.txt"

US017=$(bd create --parent="$EPIC_ID" --title="US-017: UI polish — sleek and animated" \
  --body-file="$DESC_DIR/us017.txt" --priority=3 --silent)
echo "US-017: $US017"

# --- US-018 ---
cat > "$DESC_DIR/us018.txt" << 'DESCEOF'
As a user, I want to add a task, start a timer, and add a note with minimal steps so that core actions stay fast.

## Acceptance Criteria
- [ ] Adding a task requires minimal steps (no unnecessary modals or configuration for the default case).
- [ ] Starting a timer is one or two actions from the task.
- [ ] Adding a note is minimal steps from menu bar or main app.
- [ ] No mandatory multi-step setup for core flows beyond optional preferences.
DESCEOF
echo -n "$QG" >> "$DESC_DIR/us018.txt"
echo -n "$QG_UI" >> "$DESC_DIR/us018.txt"

US018=$(bd create --parent="$EPIC_ID" --title="US-018: Simple flows — minimal steps" \
  --body-file="$DESC_DIR/us018.txt" --priority=3 --silent)
echo "US-018: $US018"

# --- Dependencies (implementation order: core day + tasks + timer, then menu bar, streaks/retro, polish/export) ---
echo "Adding dependencies..."

bd dep add "$US003" "$US001"    # US-003 depends on US-001 (tasks need day)
bd dep add "$US004" "$US003"    # US-004 depends on US-003 (timer needs tasks)
bd dep add "$US005" "$US004"    # US-005 depends on US-004 (count-up needs timer)
bd dep add "$US006" "$US003"    # US-006 depends on US-003 (rollover needs tasks)
bd dep add "$US002" "$US003"    # US-002 depends on US-003 (EOD reminder needs tasks)
bd dep add "$US002" "$US001"    # US-002 depends on US-001 (day)
bd dep add "$US007" "$US003"    # US-007 depends on US-003 (archive needs tasks)
bd dep add "$US008" "$US003"    # US-008 depends on US-003 (Eisenhower needs tasks)
bd dep add "$US009" "$US003"    # US-009 depends on US-003 (streak needs usage/tasks)
bd dep add "$US010" "$US005"    # US-010 depends on US-005 (retro needs time data)
bd dep add "$US010" "$US003"    # US-010 depends on US-003
bd dep add "$US011" "$US004"    # US-011 depends on US-004 (menu bar timer)
bd dep add "$US011" "$US005"    # US-011 depends on US-005
bd dep add "$US012" "$US003"    # US-012 depends on US-003 (quick-add needs tasks)
bd dep add "$US013" "$US014"    # US-013 depends on US-014 (menu bar notes need notes)
bd dep add "$US014" "$US001"    # US-014 depends on US-001 (notes can tie to day)
bd dep add "$US016" "$US003"    # US-016 depends on US-003 (export needs tasks)
bd dep add "$US016" "$US005"    # US-016 depends on US-005 (export time)
bd dep add "$US016" "$US014"    # US-016 depends on US-014 (export notes)
bd dep add "$US017" "$US004"    # US-017 depends on US-004 (polish after core UI)
bd dep add "$US018" "$US005"    # US-018 depends on US-005 (simple flows after timer)

echo "Done. Epic: $EPIC_ID"
echo "Run: bd ready  # or ralph-tui run --tracker beads --epic $EPIC_ID"
