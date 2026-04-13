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
    case challenge = "Challenge"
    case retrospective = "Retrospective"
    case project = "Project"
    case settings = "Settings"
    case future = "Future"
    case goals = "Goals"
    var id: String { rawValue }
}

struct ContentView: View {
    @Environment(DayStore.self) private var dayStore
    @Environment(TimerStore.self) private var timerStore
    @Environment(StreakStore.self) private var streakStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \PlanDay.date, order: .reverse) private var days: [PlanDay]
    @Query(sort: \Challenge.startDate, order: .reverse) private var challenges: [Challenge]
    @State private var sidebarSelection: SidebarItem? = .today
    @State private var challengeForMarkToday: Challenge?
    @State private var showMoveFromPastDaySheet = false
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

    /// Challenges that are active today (today's date is within the challenge range).
    private var activeChallengesToday: [Challenge] {
        let todayStart = calendar.startOfDay(for: Date())
        return challenges.filter { $0.dayIndex(for: todayStart) != nil }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailContent
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
        .sheet(item: $challengeForMarkToday) { challenge in
            let dayIndex = challenge.dayIndex(for: Date()) ?? 1
            let existing = challenge.dayProgress.first { $0.dayIndex == dayIndex }
            DayProgressSheet(
                challenge: challenge,
                dayIndex: dayIndex,
                existingProgress: existing,
                onSave: { notes, isCompleted in
                    saveChallengeDayProgress(challenge: challenge, dayIndex: dayIndex, notes: notes, isCompleted: isCompleted)
                    challengeForMarkToday = nil
                },
                onCancel: { challengeForMarkToday = nil }
            )
            .frame(minWidth: 400, minHeight: 260)
            .presentationCornerRadius(12)
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

    private func saveChallengeDayProgress(challenge: Challenge, dayIndex: Int, notes: String, isCompleted: Bool) {
        if let existing = challenge.dayProgress.first(where: { $0.dayIndex == dayIndex }) {
            existing.notes = notes
            existing.isCompleted = isCompleted
            existing.updatedAt = Date()
        } else {
            let progress = ChallengeDayProgress(dayIndex: dayIndex, notes: notes, isCompleted: isCompleted, challenge: challenge)
            modelContext.insert(progress)
            challenge.dayProgress.append(progress)
        }
        try? modelContext.save()
    }

    /// Creates a task on today's plan from the challenge and starts the count-up timer; switches to Today view.
    private func makeChallengeTask(_ challenge: Challenge) {
        dayStore.ensureTodayExists(modelContext: modelContext)
        guard let todayPlan = dayStore.fetchDay(for: Date(), modelContext: modelContext) else { return }
        let nextOrder = (todayPlan.tasks.filter { $0.parent == nil }.map(\.sortOrder).max() ?? -1) + 1
        let task = PlanTask(
            title: challenge.title,
            sortOrder: nextOrder,
            planDay: todayPlan,
            parent: nil,
            quadrant: .importantUrgent
        )
        task.linkedChallenge = challenge
        modelContext.insert(task)
        todayPlan.tasks.append(task)
        try? modelContext.save()
        timerStore.startCountUp(task: task, modelContext: modelContext)
        streakStore.recordUsage()
        sidebarSelection = .today
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
                NavigationLink(value: SidebarItem.challenge) {
                    Label("Challenge", systemImage: "flag.checkered")
                }
                NavigationLink(value: SidebarItem.retrospective) {
                    Label("Retrospective", systemImage: "arrow.triangle.2.circlepath")
                }
                NavigationLink(value: SidebarItem.project) {
                    Label("Project", systemImage: "folder.badge.gearshape")
                }
                NavigationLink(value: SidebarItem.settings) {
                    Label("Settings", systemImage: "gearshape")
                }
                NavigationLink(value: SidebarItem.future) {
                    Label("Future", systemImage: "calendar.badge.clock")
                }
                NavigationLink(value: SidebarItem.goals) {
                    Label("Goals", systemImage: "target")
                }
            }

            Section("Active challenges") {
                if activeChallengesToday.isEmpty {
                    Text("No active challenges today")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(activeChallengesToday) { challenge in
                        ActiveChallengeSidebarRow(
                            challenge: challenge,
                            onMarkToday: { challengeForMarkToday = challenge },
                            onMakeTask: { makeChallengeTask(challenge) }
                        )
                    }
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
            case .challenge:
                ChallengeListView()
            case .retrospective:
                RetrospectiveView()
            case .project:
                NavigationStack {
                    ProjectHubView()
                }
            case .settings:
                SettingsView()
            case .future:
                FutureView(onMoveToToday: { sidebarSelection = .today })
            case .goals:
                GoalsView(onMakeTodayTask: { sidebarSelection = .today })
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
                    Button("Copy from past day…") {
                        showMoveFromPastDaySheet = true
                    }
                    .disabled(displayedPlanDay == nil)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Export…") {
                    ExportService.exportToCSV(modelContext: modelContext)
                }
            }
        }
    }

}

// MARK: - Active challenge sidebar row

private struct ActiveChallengeSidebarRow: View {
    let challenge: Challenge
    let onMarkToday: () -> Void
    let onMakeTask: () -> Void

    private let calendar = Calendar.current

    private var todayDayIndex: Int? {
        challenge.dayIndex(for: Date())
    }

    private var todayProgress: ChallengeDayProgress? {
        guard let idx = todayDayIndex else { return nil }
        return challenge.dayProgress.first { $0.dayIndex == idx }
    }

    private var isTodayMarked: Bool {
        todayProgress?.isCompleted == true
    }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(challenge.title)
                    .font(.subheadline)
                    .lineLimit(1)
                if let idx = todayDayIndex {
                    Text("Day \(idx) of \(challenge.totalDays)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 4)
            Button {
                onMarkToday()
            } label: {
                Image(systemName: isTodayMarked ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(isTodayMarked ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .help(isTodayMarked ? "Today marked" : "Mark today")
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button {
                onMakeTask()
            } label: {
                Label("Make task", systemImage: "timer")
            }
            .help("Add this challenge as a task on Today and start the timer")
        }
    }
}

struct DayPlanView: View {
    @Bindable var planDay: PlanDay
    /// When false, header uses "this day" instead of "today".
    var isSelectedDateToday: Bool = true
    @Environment(\.modelContext) private var modelContext
    @Environment(TimerStore.self) private var timerStore
    @Environment(StreakStore.self) private var streakStore
    @Environment(DayStore.self) private var dayStore
    @Query(sort: \PlanGoal.sortOrder, order: .forward) private var allGoals: [PlanGoal]
    @State private var newTaskTitle = ""
    @State private var newTaskQuadrant: EisenhowerQuadrant = AppTaskSettings.defaultQuadrant
    @State private var editingTaskId: PersistentIdentifier?
    @State private var showAddTaskSheet = false
    @State private var fabTaskTitle = ""
    @State private var fabTaskQuadrant: EisenhowerQuadrant = AppTaskSettings.defaultQuadrant

    private static var calendar: Calendar { .current }

    private static func currentMonthStart() -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
    }

    private var currentWeekNumber: Int {
        let dayOfMonth = Self.calendar.component(.day, from: Date())
        let weekNum = ((dayOfMonth - 1) / 7) + 1
        return min(max(weekNum, 1), 4)
    }

    private var currentWeekGoals: [PlanGoal] {
        guard isSelectedDateToday else { return [] }
        let monthStart = Self.currentMonthStart()
        return allGoals.filter { goal in
            Self.calendar.isDate(goal.month, inSameDayAs: monthStart) && goal.weekNumber == currentWeekNumber
        }.sorted { g1, g2 in
            if g1.isCompleted != g2.isCompleted { return !g1.isCompleted }
            return g1.sortOrder < g2.sortOrder
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                if timerStore.activeTaskID != nil {
                    activeTaskCard
                }
                if isSelectedDateToday, !currentWeekGoals.isEmpty {
                    currentWeekGoalsSection
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
        .overlay(alignment: .bottomTrailing) {
            Button {
                fabTaskTitle = ""
                fabTaskQuadrant = newTaskQuadrant
                showAddTaskSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .frame(width: 56, height: 56)
                    .background(.tint, in: Circle())
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(24)
        }
        .sheet(isPresented: $showAddTaskSheet) {
            AddTaskSheetView(
                title: $fabTaskTitle,
                quadrant: $fabTaskQuadrant,
                onAdd: {
                    addTaskWith(title: fabTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines), quadrant: fabTaskQuadrant)
                    if !fabTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        showAddTaskSheet = false
                        fabTaskTitle = ""
                    }
                },
                onCancel: {
                    showAddTaskSheet = false
                    fabTaskTitle = ""
                }
            )
            .frame(minWidth: 360, minHeight: 200)
            .presentationCornerRadius(12)
        }
        .onAppear {
            let preferredQuadrant = AppTaskSettings.defaultQuadrant
            newTaskQuadrant = preferredQuadrant
            fabTaskQuadrant = preferredQuadrant
        }
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
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Text(totalTimeTodayLabel)
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Text(totalTodayFormattedDisplay)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .monospacedDigit()
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

    private var totalTimeTodayLabel: String {
        isSelectedDateToday ? "Total today:" : "Time logged:"
    }

    private var totalTodayFormattedDisplay: String {
        let total = totalTodaySeconds
        let h = Int(total) / 3600
        let m = (Int(total) % 3600) / 60
        if h > 0 {
            return "\(h)h \(m)m"
        }
        return "\(m)m"
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
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Spacer()
                if totalTodayFormatted != nil {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Total today")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Text(totalTodayFormatted ?? "0m")
                            .font(.title)
                            .fontWeight(.semibold)
                            .monospacedDigit()
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
                Button("Complete") {
                    let activeID = timerStore.activeTaskID
                    timerStore.stopAndRecord(modelContext: modelContext)
                    if let id = activeID,
                       let task = modelContext.model(for: id) as? PlanTask {
                        task.isCompleted = true
                        try? modelContext.save()
                    }
                    streakStore.recordUsage()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
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

    private var currentWeekGoalsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "circle.hexagongrid.fill")
                    .font(.body)
                    .foregroundStyle(.secondary)
                Text("This week's goals")
                    .font(.headline)
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(currentWeekGoals, id: \.id) { goal in
                    HStack(spacing: 10) {
                        Image(systemName: goal.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.body)
                            .foregroundStyle(goal.isCompleted ? .green : .secondary)
                        Text(goal.title)
                            .font(.subheadline)
                            .strikethrough(goal.isCompleted)
                            .foregroundStyle(goal.isCompleted ? .secondary : .primary)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            makeGoalTodayTask(goal)
                        } label: {
                            Image(systemName: "sun.max")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .help("Add to today's tasks")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func makeGoalTodayTask(_ goal: PlanGoal) {
        dayStore.ensureTodayExists(modelContext: modelContext)
        guard let todayPlan = dayStore.fetchDay(for: Date(), modelContext: modelContext) else { return }
        let nextOrder = (todayPlan.tasks.filter { $0.parent == nil }.map(\.sortOrder).max() ?? -1) + 1
        let task = PlanTask(
            title: goal.title,
            sortOrder: nextOrder,
            planDay: todayPlan,
            parent: nil,
            quadrant: .notImportantNotUrgent
        )
        modelContext.insert(task)
        todayPlan.tasks.append(task)
        try? modelContext.save()
    }

    private var addTaskBar: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                Spacer()
                Button("+ New Task") { addTask() }
                    .buttonStyle(.borderedProminent)
            }
            ZStack(alignment: .topLeading) {
                if newTaskTitle.isEmpty {
                    Text("New task…")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $newTaskTitle)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(4)
                    .frame(minHeight: 64, maxHeight: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(.quaternary, lineWidth: 1)
                    )
                    .onKeyPress { press in
                        guard press.key == .return else { return .ignored }
                        if press.modifiers.contains(.shift) { return .ignored }
                        addTask()
                        return .handled
                    }
            }
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
                VStack(alignment: .leading, spacing: 10) {
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
        .padding(20)
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
        addTaskWith(title: title, quadrant: newTaskQuadrant)
        newTaskTitle = ""
    }

    private func addTaskWith(title: String, quadrant: EisenhowerQuadrant) {
        guard !title.isEmpty else { return }
        let nextOrder = (planDay.tasks.filter { $0.parent == nil }.map(\.sortOrder).max() ?? -1) + 1
        let task = PlanTask(title: title, sortOrder: nextOrder, planDay: planDay, parent: nil, quadrant: quadrant)
        withAnimation(.easeOut(duration: 0.22)) {
            modelContext.insert(task)
            planDay.tasks.append(task)
        }
        try? modelContext.save()
        streakStore.recordUsage()
    }
}

// MARK: - Add task sheet (FAB)

private struct AddTaskSheetView: View {
    @Binding var title: String
    @Binding var quadrant: EisenhowerQuadrant
    var onAdd: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New task")
                .font(.headline)
            Menu {
                ForEach(EisenhowerQuadrant.matrixDisplayOrder, id: \.rawValue) { q in
                    Button {
                        quadrant = q
                    } label: {
                        HStack {
                            Image(systemName: q.systemImage)
                                .foregroundStyle(q.accentColor)
                            Text(q.shortTitle)
                            if quadrant == q {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: quadrant.systemImage)
                        .foregroundStyle(quadrant.accentColor)
                    Text(quadrant.shortTitle)
                        .font(.subheadline)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(.quaternary.opacity(0.8), in: RoundedRectangle(cornerRadius: 6))
            }
            .menuStyle(.borderlessButton)
            ZStack(alignment: .topLeading) {
                if title.isEmpty {
                    Text("Task title…")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $title)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(4)
                    .frame(minHeight: 64, maxHeight: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(.quaternary, lineWidth: 1)
                    )
                    .onKeyPress { press in
                        guard press.key == .return else { return .ignored }
                        if press.modifiers.contains(.shift) { return .ignored }
                        onAdd()
                        return .handled
                    }
            }
            HStack(spacing: 10) {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Add task") {
                    onAdd()
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
    }
}

// MARK: - Copy from past day

struct MoveFromPastDaySheet: View {
    var dayStore: DayStore
    /// Day to copy incomplete tasks into (e.g. the currently viewed day).
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
                        description: Text("Past days have no uncompleted tasks to copy.")
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
            .navigationTitle(Calendar.current.isDateInToday(targetDay.date) ? "Copy to today" : "Copy to this day")
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
        .modelContainer(for: [
            PlanDay.self,
            PlanTask.self,
            PlanNote.self,
            Project.self,
            ProjectKanbanColumn.self,
            ProjectKanbanCard.self,
            ProjectSprint.self,
            ProjectRetrospective.self,
            ProjectTimelineEvent.self,
            ProjectDocument.self,
            RetrospectiveEntry.self,
            Challenge.self,
            ChallengeDayProgress.self,
            ChallengeRetrospective.self,
            FutureTask.self,
            PlanGoal.self,
        ], inMemory: true)
}
