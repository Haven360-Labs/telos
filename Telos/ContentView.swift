import SwiftUI
import SwiftData
import AppKit

struct ContentView: View {
    @Environment(DayStore.self) private var dayStore
    @Environment(TimerStore.self) private var timerStore
    @Environment(StreakStore.self) private var streakStore
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlanDay.date, order: .reverse) private var days: [PlanDay]
    @State private var showAddNoteSheet = false
    @State private var quickNoteContent = ""

    var body: some View {
        NavigationStack {
            Group {
                if let today = days.first(where: { Calendar.current.isDateInToday($0.date) }) {
                    DayPlanView(planDay: today)
                } else {
                    ContentUnavailableView(
                        "No plan for today",
                        systemImage: "sun.max",
                        description: Text("Today’s plan will appear here.")
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink("Retrospective") {
                        RetrospectiveView()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink("Notes") {
                        NotesListView()
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
        VStack(alignment: .leading, spacing: 20) {
            if timerStore.activeTaskID != nil {
                HStack(spacing: 12) {
                    Image(systemName: "timer")
                        .foregroundStyle(.orange)
                    Text(timerStore.activeTaskTitle ?? "Task")
                        .lineLimit(1)
                        .fontWeight(.medium)
                    Text(activeTimerText)
                        .font(.title2.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Stop") {
                        timerStore.stopAndRecord(modelContext: modelContext)
                        streakStore.recordUsage()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(12)
                .background(.quaternary.opacity(0.8), in: RoundedRectangle(cornerRadius: 10))
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
            }

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(planDay.date, style: .date)
                    .font(.title2)
                if streakStore.currentStreak > 0 {
                    Text("\(streakStore.currentStreak) day streak")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                TextField("New task", text: $newTaskTitle)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addTask() }
                Button("Add task") { addTask() }
                    .buttonStyle(.bordered)
            }

            if planDay.sortedTopLevelTasks.isEmpty {
                Text("No tasks yet. Add one above.")
                    .foregroundStyle(.secondary)
            } else {
                List {
                    ForEach(EisenhowerQuadrant.allCases) { q in
                        Section {
                            ForEach(planDay.topLevelTasks(in: q)) { task in
                                TaskRowView(task: task, timerStore: timerStore)
                            }
                        } header: {
                            HStack(spacing: 6) {
                                Text(q.fullTitle)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                if !planDay.topLevelTasks(in: q).isEmpty {
                                    Text("(\(planDay.topLevelTasks(in: q).count))")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding()
        .navigationTitle("Today")
        .animation(.easeInOut(duration: 0.28), value: timerStore.activeTaskID != nil)
    }

    /// Subscribes to countUpTick when count-up so the bar re-renders every second.
    private var activeTimerText: String {
        if timerStore.isCountUp {
            _ = timerStore.countUpTick
            return "\(timerStore.formattedElapsed) elapsed"
        }
        return "\(timerStore.formattedRemaining) left"
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
