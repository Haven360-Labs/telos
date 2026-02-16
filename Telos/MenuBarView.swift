import SwiftUI
import SwiftData

struct MenuBarView: View {
    @Environment(DayStore.self) private var dayStore
    @Environment(TimerStore.self) private var timerStore
    @Environment(StreakStore.self) private var streakStore
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlanNote.createdAt, order: .reverse) private var notes: [PlanNote]
    @State private var showQuickAdd = false
    @State private var quickAddTitle = ""
    @State private var quickAddQuadrant: EisenhowerQuadrant = .notImportantNotUrgent
    @State private var showAddNote = false
    @State private var noteContent = ""

    private var recentNotes: [PlanNote] { Array(notes.prefix(5)) }

    private var activeTimerSubtitle: String {
        if timerStore.isPaused { return "Paused" }
        if timerStore.isCountUp {
            _ = timerStore.countUpTick
            return "\(timerStore.formattedElapsed) elapsed"
        }
        return "\(timerStore.formattedRemaining) left"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if timerStore.activeTaskID != nil {
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(timerStore.activeTaskTitle ?? "Task")
                            .font(.subheadline)
                            .lineLimit(1)
                        Text(activeTimerSubtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Spacer()
                }
                .padding(.vertical, 4)
                HStack(spacing: 8) {
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
                Divider()
            }
            Text("Today's plan")
                .font(.headline)
            Button("Quick add task") {
                quickAddTitle = ""
                showQuickAdd = true
            }
            .keyboardShortcut("n", modifiers: [.command])
            if showQuickAdd {
                VStack(alignment: .leading, spacing: 6) {
                    Menu {
                        ForEach(EisenhowerQuadrant.matrixDisplayOrder, id: \.rawValue) { q in
                            Button {
                                quickAddQuadrant = q
                            } label: {
                                HStack {
                                    Image(systemName: q.systemImage)
                                        .foregroundStyle(q.accentColor)
                                    Text(q.shortTitle)
                                    if quickAddQuadrant == q {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: quickAddQuadrant.systemImage)
                                .foregroundStyle(quickAddQuadrant.accentColor)
                            Text(quickAddQuadrant.shortTitle)
                                .font(.caption)
                        }
                    }
                    .menuStyle(.borderlessButton)
                    HStack(spacing: 6) {
                        TextField("Task title", text: $quickAddTitle)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit { submitQuickAdd() }
                        Button("Add") { submitQuickAdd() }
                    }
                }
                .padding(.vertical, 4)
            }
            Divider()
            Text("Notes")
                .font(.headline)
            Button("Add note") {
                noteContent = ""
                showAddNote = true
            }
            if showAddNote {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("Note", text: $noteContent, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                        .onSubmit { submitAddNote() }
                    Button("Save note") { submitAddNote() }
                }
                .padding(.vertical, 4)
            }
            if !recentNotes.isEmpty {
                Text("Recent notes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(recentNotes) { note in
                    Button {
                        NSApplication.shared.activate(ignoringOtherApps: true)
                    } label: {
                        Text(note.preview)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
            Divider()
            Button("Open Telos") {
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 280)
    }

    private func submitQuickAdd() {
        let title = quickAddTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        dayStore.ensureTodayExists(modelContext: modelContext)
        guard let today = fetchToday() else { return }
        let nextOrder = (today.tasks.filter { $0.parent == nil }.map(\.sortOrder).max() ?? -1) + 1
        let task = PlanTask(title: title, sortOrder: nextOrder, planDay: today, parent: nil, quadrant: quickAddQuadrant)
        modelContext.insert(task)
        today.tasks.append(task)
        try? modelContext.save()
        quickAddTitle = ""
        showQuickAdd = false
        streakStore.recordUsage()
    }

    private func submitAddNote() {
        let content = noteContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        let note = PlanNote(content: content)
        modelContext.insert(note)
        try? modelContext.save()
        noteContent = ""
        showAddNote = false
        streakStore.recordUsage()
    }

    private func fetchToday() -> PlanDay? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        var descriptor = FetchDescriptor<PlanDay>(
            predicate: #Predicate<PlanDay> { day in
                day.date >= today && day.date < tomorrow
            }
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first
    }
}
