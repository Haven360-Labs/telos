import SwiftUI
import SwiftData
import AppKit

private enum SidebarItem: String, CaseIterable, Identifiable {
    case today = "Today"
    case notes = "Notes"
    case retrospective = "Retrospective"
    var id: String { rawValue }
}

struct ContentView: View {
    @Environment(DayStore.self) private var dayStore
    @Environment(TimerStore.self) private var timerStore
    @Environment(StreakStore.self) private var streakStore
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlanDay.date, order: .reverse) private var days: [PlanDay]
    @State private var sidebarSelection: SidebarItem? = .today
    @State private var showAddNoteSheet = false
    @State private var quickNoteContent = ""

    private var today: PlanDay? {
        days.first(where: { Calendar.current.isDateInToday($0.date) })
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
        .onAppear {
            StatusBarController.install(
                timerStore: timerStore,
                dayStore: dayStore,
                streakStore: streakStore,
                modelContainer: modelContext.container
            )
            dayStore.ensureTodayExists(modelContext: modelContext)
            streakStore.recordUsage()
            dayStore.showEndOfDayReminderIfNeeded(modelContext: modelContext)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWorkspace.didWakeNotification)) { _ in
            dayStore.showMorningReminderIfNeeded(modelContext: modelContext)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            dayStore.showEndOfDayReminderIfNeeded(modelContext: modelContext)
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
                        HStack(spacing: 4) {
                            ForEach(0 ..< min(5, streakStore.currentStreak), id: \.self) { _ in
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 6, height: 6)
                            }
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
                if let today = today {
                    DayPlanView(planDay: today)
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
            }
        }
        .toolbar {
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
    @Environment(\.modelContext) private var modelContext
    @Environment(TimerStore.self) private var timerStore
    @Environment(StreakStore.self) private var streakStore
    @State private var newTaskTitle = ""

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
        .background(.regularMaterial.opacity(0.3))
        .animation(.easeInOut(duration: 0.28), value: timerStore.activeTaskID != nil)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(planDay.date, style: .date)
                    .font(.title2)
                    .fontWeight(.semibold)
                if streakStore.currentStreak > 0 {
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
                 : "You have \(count) task\(count == 1 ? "" : "s") today. Keep up the momentum!")
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
                    ForEach(tasks) { task in
                        TaskRowView(task: task, timerStore: timerStore)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func addTask() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let nextOrder = (planDay.tasks.filter { $0.parent == nil }.map(\.sortOrder).max() ?? -1) + 1
        let task = PlanTask(title: title, sortOrder: nextOrder, planDay: planDay, parent: nil)
        withAnimation(.easeOut(duration: 0.22)) {
            modelContext.insert(task)
            planDay.tasks.append(task)
        }
        try? modelContext.save()
        newTaskTitle = ""
        streakStore.recordUsage()
    }
}

#Preview {
    ContentView()
        .environment(DayStore())
        .environment(TimerStore())
        .environment(StreakStore())
        .modelContainer(for: [PlanDay.self, PlanTask.self, PlanNote.self, RetrospectiveEntry.self], inMemory: true)
}
