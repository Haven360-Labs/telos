import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

/// Payload for drag-and-drop reorder within a quadrant.
private struct TaskDragPayload: Transferable, Codable {
    let quadrantRaw: Int
    let sourceIndex: Int

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

private enum SidebarItem: String, CaseIterable, Identifiable {
    case today = "Today"
    case notes = "Notes"
    case retrospective = "Retrospective"
    case settings = "Settings"
    var id: String { rawValue }
}

struct ContentView: View {
    @Environment(DayStore.self) private var dayStore
    @Environment(TimerStore.self) private var timerStore
    @Environment(StreakStore.self) private var streakStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \PlanDay.date, order: .reverse) private var days: [PlanDay]
    @State private var sidebarSelection: SidebarItem? = .today
    @State private var showAddNoteSheet = false
    @State private var showMoveFromPastDaySheet = false
    @State private var quickNoteContent = ""
    /// The date whose plan is shown in the day view. Start of day; defaults to today.
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())

    private var calendar: Calendar { Calendar.current }

    private var today: PlanDay? {
        days.first(where: { calendar.isDateInToday($0.date) })
    }

    /// Plan day for the currently selected date. Ensured to exist when viewing the day (see onAppear in detailContent).
    private var displayedPlanDay: PlanDay? {
        days.first(where: { calendar.isDate($0.date, inSameDayAs: selectedDate) })
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailContent
        }
        .sheet(isPresented: $showAddNoteSheet) {
            AddNoteView(content: $quickNoteContent) {
                saveQuickNote()
                showAddNoteSheet = false
            }
            .frame(minWidth: 400, minHeight: 200)
            .presentationCornerRadius(12)
        }
        .sheet(isPresented: $showMoveFromPastDaySheet) {
            if let targetDay = displayedPlanDay ?? today {
                MoveFromPastDaySheet(
                    dayStore: dayStore,
                    targetDay: targetDay,
                    pastDays: days.filter { calendar.startOfDay(for: $0.date) < calendar.startOfDay(for: targetDay.date) },
                    onDismiss: { showMoveFromPastDaySheet = false }
                )
                .environment(\.modelContext, modelContext)
                .frame(minWidth: 360, minHeight: 320)
                .presentationCornerRadius(12)
            }
        }
        .onAppear {
            StatusBarController.install(
                timerStore: timerStore,
                dayStore: dayStore,
                streakStore: streakStore,
                modelContainer: modelContext.container
            )
            dayStore.ensureTodayExists(modelContext: modelContext)
            dayStore.scheduleMorningReminder()
            streakStore.recordUsage()
            dayStore.showEndOfDayReminderIfNeeded(modelContext: modelContext)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWorkspace.didWakeNotification)) { _ in
            dayStore.scheduleMorningReminder()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            dayStore.scheduleMorningReminder()
            dayStore.showEndOfDayReminderIfNeeded(modelContext: modelContext)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                saveModelContextIfNeeded()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            timerStore.stopAndRecord(modelContext: modelContext)
            saveModelContextIfNeeded()
        }
    }

    /// Persists SwiftData changes to local storage. Call on background and before quit.
    private func saveModelContextIfNeeded() {
        if modelContext.hasChanges {
            try? modelContext.save()
        }
    }

    private var sidebar: some View {
        List(selection: $sidebarSelection) {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "sun.max.fill")
                            .font(.title2)
                            .foregroundStyle(.orange)
                        Text("Telos")
                            .font(.headline)
                    }
                    if streakStore.currentStreak > 0 {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(.orange)
                            Text("\(streakStore.currentStreak) day streak")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section {
                NavigationLink(value: SidebarItem.today) {
                    HStack {
                        Label("Today", systemImage: "sun.max")
                        Spacer()
                        if let today = today, !today.sortedTopLevelTasks.isEmpty {
                            Text("\(today.sortedTopLevelTasks.count)")
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.quaternary, in: Capsule())
                        }
                    }
                }
                NavigationLink(value: SidebarItem.notes) {
                    Label("Notes", systemImage: "note.text")
                }
                NavigationLink(value: SidebarItem.retrospective) {
                    Label("Retrospective", systemImage: "arrow.triangle.2.circlepath")
                }
                NavigationLink(value: SidebarItem.settings) {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 280)
    }

    @ViewBuilder
    private var detailContent: some View {
        Group {
            switch sidebarSelection ?? .today {
            case .today:
                if let planDay = displayedPlanDay {
                    DayPlanView(planDay: planDay, isSelectedDateToday: calendar.isDate(selectedDate, inSameDayAs: Date()))
                } else {
                    ContentUnavailableView(
                        "No plan for today",
                        systemImage: "sun.max",
                        description: Text("Today’s plan will appear here.")
                    )
                }
            case .notes:
                NotesListView()
            case .retrospective:
                RetrospectiveView()
            case .settings:
                SettingsView()
            }
        }
        .onAppear {
            if sidebarSelection == .today {
                _ = dayStore.ensureDayExists(for: selectedDate, modelContext: modelContext)
            }
        }
        .onChange(of: selectedDate) { _, _ in
            _ = dayStore.ensureDayExists(for: selectedDate, modelContext: modelContext)
        }
        .toolbar {
            if sidebarSelection == .today {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Button("Today") {
                            selectedDate = calendar.startOfDay(for: Date())
                        }
                        .buttonStyle(.bordered)
                        .disabled(calendar.isDate(selectedDate, inSameDayAs: Date()))
                        Button {
                            selectedDate = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                        } label: { Image(systemName: "chevron.left") }
                        .buttonStyle(.bordered)
                        Button {
                            let next = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                            let todayStart = calendar.startOfDay(for: Date())
                            let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart)!
                            if next <= tomorrowStart {
                                selectedDate = next
                            }
                        } label: { Image(systemName: "chevron.right") }
                        .buttonStyle(.bordered)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Move from past day…") {
                        showMoveFromPastDaySheet = true
                    }
                    .disabled(displayedPlanDay == nil)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Add note") {
                    quickNoteContent = ""
                    showAddNoteSheet = true
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Export…") {
                    ExportService.exportToCSV(modelContext: modelContext)
                }
            }
        }
    }

    private func saveQuickNote() {
        let content = quickNoteContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        let note = PlanNote(content: content)
        modelContext.insert(note)
        try? modelContext.save()
        streakStore.recordUsage()
    }
}

struct DayPlanView: View {
    @Bindable var planDay: PlanDay
    /// When false, header uses "this day" instead of "today".
    var isSelectedDateToday: Bool = true
    @Environment(\.modelContext) private var modelContext
    @Environment(TimerStore.self) private var timerStore
    @Environment(StreakStore.self) private var streakStore
    @State private var newTaskTitle = ""
    @State private var newTaskQuadrant: EisenhowerQuadrant = .notImportantNotUrgent
    @State private var editingTaskId: PersistentIdentifier?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if timerStore.activeTaskID != nil {
                    activeTaskCard
                }
                addTaskBar
                if planDay.sortedTopLevelTasks.isEmpty {
                    emptyState
                } else {
                    matrixSection
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                editingTaskId = nil
            }
        )
        .background(.regularMaterial.opacity(0.3))
        .animation(.easeInOut(duration: 0.28), value: timerStore.activeTaskID != nil)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(planDay.date, style: .date)
                    .font(.title2)
                    .fontWeight(.semibold)
                if isSelectedDateToday, streakStore.currentStreak > 0 {
                    Text("Day \(streakStore.currentStreak)")
                        .font(.subheadline)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.quaternary, in: Capsule())
                }
            }
            let count = planDay.sortedTopLevelTasks.count
            Text(count == 0
                 ? "Add tasks to plan your day."
                 : "You have \(count) task\(count == 1 ? "" : "s") \(isSelectedDateToday ? "today" : "this day"). Keep up the momentum!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var activeTaskCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(.blue)
                    .frame(width: 8, height: 8)
                Text("Active Task")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            Text(timerStore.activeTaskTitle ?? "Task")
                .font(.title3)
                .fontWeight(.semibold)
                .lineLimit(1)
            Text(activeTaskSubtitle)
                .font(.caption)
                .foregroundStyle(.tertiary)
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(activeTimerDisplay)
                    .font(.system(size: 42, weight: .light, design: .rounded))
                    .monospacedDigit()
                Spacer()
                if totalTodayFormatted != nil {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Total today")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(totalTodayFormatted ?? "0m")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                }
            }
            HStack(spacing: 10) {
                if timerStore.isPaused {
                    Button("Resume") {
                        timerStore.resume(modelContext: modelContext)
                        streakStore.recordUsage()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                } else {
                    Button("Pause") {
                        timerStore.pause()
                    }
                    .buttonStyle(.bordered)
                }
                Button("Stop") {
                    timerStore.stopAndRecord(modelContext: modelContext)
                    streakStore.recordUsage()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.blue.opacity(0.3), lineWidth: 1)
        )
    }

    private var activeTaskSubtitle: String {
        if timerStore.isPaused {
            return "Paused"
        }
        if timerStore.isCountUp {
            return "Focus mode · Count up"
        }
        return "Countdown · \(timerStore.formattedRemaining) left"
    }

    private var activeTimerDisplay: String {
        if timerStore.isCountUp {
            _ = timerStore.countUpTick
            return timerStore.formattedElapsed
        }
        return timerStore.formattedRemaining
    }

    private var totalTodayFormatted: String? {
        let total = totalTodaySeconds
        guard total > 0 else { return nil }
        let h = Int(total) / 3600
        let m = (Int(total) % 3600) / 60
        if h > 0 {
            return "\(h)h \(m)m"
        }
        return "\(m)m"
    }

    private var totalTodaySeconds: Double {
        let fromTasks = planDay.tasks.reduce(0.0) { $0 + $1.timeSpentSeconds }
        guard timerStore.isCountUp, timerStore.activeTaskID != nil else { return fromTasks }
        guard let id = timerStore.activeTaskID,
              let task = modelContext.model(for: id) as? PlanTask,
              let day = task.planDay, Calendar.current.isDateInToday(day.date) else { return fromTasks }
        return fromTasks + timerStore.countUpElapsedSeconds
    }

    private var addTaskBar: some View {
        HStack(spacing: 10) {
            Menu {
                ForEach(EisenhowerQuadrant.matrixDisplayOrder, id: \.rawValue) { q in
                    Button {
                        newTaskQuadrant = q
                    } label: {
                        HStack {
                            Image(systemName: q.systemImage)
                                .foregroundStyle(q.accentColor)
                            Text(q.shortTitle)
                            if newTaskQuadrant == q {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: newTaskQuadrant.systemImage)
                        .foregroundStyle(newTaskQuadrant.accentColor)
                    Text(newTaskQuadrant.shortTitle)
                        .font(.subheadline)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.quaternary.opacity(0.8), in: RoundedRectangle(cornerRadius: 6))
            }
            .menuStyle(.borderlessButton)
            TextField("New task", text: $newTaskTitle)
                .textFieldStyle(.roundedBorder)
                .onSubmit { addTask() }
            Button("+ New Task") { addTask() }
                .buttonStyle(.borderedProminent)
        }
    }

    private var emptyState: some View {
        Text("No tasks yet. Add one above.")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 20)
    }

    private var matrixSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(EisenhowerQuadrant.matrixDisplayOrder, id: \.rawValue) { q in
                quadrantCard(quadrant: q)
            }
        }
    }

    private func quadrantCard(quadrant q: EisenhowerQuadrant) -> some View {
        let tasks = planDay.topLevelTasksForDisplay(in: q)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: q.systemImage)
                    .font(.body)
                    .foregroundStyle(q.accentColor)
                Text(q.shortTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                if !tasks.isEmpty {
                    Text("\(tasks.count)")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
            }
            if tasks.isEmpty {
                Text("No tasks")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                        TaskRowView(task: task, timerStore: timerStore, editingTaskId: $editingTaskId)
                            .draggable(TaskDragPayload(quadrantRaw: q.rawValue, sourceIndex: index))
                            .dropDestination(for: TaskDragPayload.self) { payloads, _ in
                                guard let payload = payloads.first,
                                      payload.quadrantRaw == q.rawValue,
                                      payload.sourceIndex != index else { return false }
                                let toIdx = payload.sourceIndex < index ? index - 1 : index
                                moveTasks(in: q, from: IndexSet(integer: payload.sourceIndex), to: toIdx)
                                return true
                            } isTargeted: { _ in }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func moveTasks(in quadrant: EisenhowerQuadrant, from source: IndexSet, to destination: Int) {
        var tasks = planDay.topLevelTasksForDisplay(in: quadrant)
        let incompleteCount = tasks.filter { !$0.isCompleted }.count
        guard let fromIdx = source.first, fromIdx < tasks.count else { return }
        var toIdx = destination
        if fromIdx < incompleteCount {
            toIdx = min(max(toIdx, 0), incompleteCount - 1)
        } else {
            toIdx = min(max(toIdx, incompleteCount), tasks.count - 1)
        }
        let task = tasks.remove(at: fromIdx)
        tasks.insert(task, at: toIdx)
        for (i, t) in tasks.enumerated() {
            t.sortOrder = i
        }
        try? modelContext.save()
    }

    private func addTask() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let nextOrder = (planDay.tasks.filter { $0.parent == nil }.map(\.sortOrder).max() ?? -1) + 1
        let task = PlanTask(title: title, sortOrder: nextOrder, planDay: planDay, parent: nil, quadrant: newTaskQuadrant)
        withAnimation(.easeOut(duration: 0.22)) {
            modelContext.insert(task)
            planDay.tasks.append(task)
        }
        try? modelContext.save()
        newTaskTitle = ""
        streakStore.recordUsage()
    }
}

// MARK: - Move from past day

struct MoveFromPastDaySheet: View {
    var dayStore: DayStore
    /// Day to move incomplete tasks into (e.g. the currently viewed day).
    var targetDay: PlanDay
    var pastDays: [PlanDay]
    var onDismiss: () -> Void
    @Environment(\.modelContext) private var modelContext

    /// Past days that have at least one incomplete top-level task, most recent first.
    private var pastDaysWithIncomplete: [(day: PlanDay, count: Int)] {
        pastDays
            .map { day in (day: day, count: day.tasks.filter { $0.parent == nil && !$0.isCompleted && !$0.isArchived }.count) }
            .filter { $0.count > 0 }
            .sorted { $0.day.date > $1.day.date }
    }

    var body: some View {
        NavigationStack {
            Group {
                if pastDaysWithIncomplete.isEmpty {
                    ContentUnavailableView(
                        "No incomplete tasks in past days",
                        systemImage: "calendar.badge.checkmark",
                        description: Text("Past days have no uncompleted tasks to move.")
                    )
                } else {
                    List {
                        ForEach(pastDaysWithIncomplete, id: \.day.persistentModelID) { item in
                            Button {
                                moveFrom(item.day)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.day.date, style: .date)
                                            .font(.body)
                                        Text("\(item.count) incomplete task\(item.count == 1 ? "" : "s")")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.right.circle")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .navigationTitle(Calendar.current.isDateInToday(targetDay.date) ? "Move to today" : "Move to this day")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onDismiss() }
                }
            }
        }
    }

    private func moveFrom(_ sourceDay: PlanDay) {
        _ = dayStore.moveIncompleteTasks(from: sourceDay.date, to: targetDay, modelContext: modelContext)
        onDismiss()
    }
}

#Preview {
    ContentView()
        .environment(DayStore())
        .environment(TimerStore())
        .environment(StreakStore())
        .modelContainer(for: [PlanDay.self, PlanTask.self, PlanNote.self, RetrospectiveEntry.self], inMemory: true)
}
