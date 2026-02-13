import SwiftUI
import SwiftData

struct TaskRowView: View {
    @Bindable var task: PlanTask
    var timerStore: TimerStore
    @Environment(\.modelContext) private var modelContext
    @Environment(StreakStore.self) private var streakStore
    @State private var isAddingSubtask = false
    @State private var newSubtaskTitle = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        task.isCompleted.toggle()
                    }
                    try? modelContext.save()
                } label: {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(task.isCompleted ? .green : .secondary)
                }
                .buttonStyle(.plain)

                Text(task.title)
                    .strikethrough(task.isCompleted)
                    .foregroundStyle(task.isCompleted ? .secondary : .primary)

                if task.parent == nil {
                    Menu {
                        ForEach(EisenhowerQuadrant.allCases) { q in
                            Button {
                                task.quadrant = q
                                try? modelContext.save()
                            } label: {
                                if task.quadrant == q {
                                    Label(q.shortTitle, systemImage: "checkmark")
                                } else {
                                    Text(q.shortTitle)
                                }
                            }
                        }
                    } label: {
                        Text(task.quadrant.shortTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.quaternary.opacity(0.8), in: RoundedRectangle(cornerRadius: 4))
                    }
                    .menuStyle(.borderlessButton)
                }

                if task.isRolledOver {
                    Text("Yesterday")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }

                if task.timeSpentSeconds > 0 {
                    Text(formatTimeSpent(task.timeSpentSeconds))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    if timerStore.isActive(task: task) { return }
                    timerStore.startCountUp(task: task, modelContext: modelContext)
                    streakStore.recordUsage()
                } label: {
                    Image(systemName: timerStore.isActive(task: task) ? "timer" : "play.circle")
                        .foregroundStyle(timerStore.isActive(task: task) ? .orange : .secondary)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button("Count up") {
                        if !timerStore.isActive(task: task) {
                            timerStore.startCountUp(task: task, modelContext: modelContext)
                            streakStore.recordUsage()
                        }
                    }
                    Section("Countdown") {
                        ForEach([15, 25, 45], id: \.self) { minutes in
                            Button("\(minutes) min") {
                                if !timerStore.isActive(task: task) {
                                    timerStore.startCountdown(task: task, durationMinutes: minutes, modelContext: modelContext)
                                    streakStore.recordUsage()
                                }
                            }
                        }
                    }
                }

                if task.parent == nil {
                    Button {
                        isAddingSubtask = true
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.body)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
            .contextMenu {
                Button(role: .destructive) {
                    markAsNoLongerNeeded()
                } label: {
                    Label("Mark as no longer needed", systemImage: "archivebox")
                }
            }

            if !task.subtasks.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(task.subtasksForDisplay) { subtask in
                        TaskRowView(task: subtask, timerStore: timerStore)
                            .padding(.leading, 24)
                    }
                }
            }

            if isAddingSubtask {
                HStack(spacing: 8) {
                    TextField("Subtask title", text: $newSubtaskTitle)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addSubtask() }
                    Button("Add") { addSubtask() }
                    Button("Cancel") {
                        isAddingSubtask = false
                        newSubtaskTitle = ""
                    }
                    .keyboardShortcut(.cancelAction)
                }
                .padding(.leading, 32)
                .padding(.vertical, 4)
            }
        }
    }

    private func markAsNoLongerNeeded() {
        if timerStore.isActive(task: task) {
            timerStore.stopAndRecord(modelContext: modelContext)
        }
        task.isArchived = true
        for subtask in task.subtasks {
            subtask.isArchived = true
        }
        try? modelContext.save()
    }

    private func formatTimeSpent(_ seconds: Double) -> String {
        let m = Int(seconds / 60)
        let s = Int(seconds.truncatingRemainder(dividingBy: 60))
        return "\(m)m \(s)s"
    }

    private func addSubtask() {
        let title = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let nextOrder = (task.subtasks.map(\.sortOrder).max() ?? -1) + 1
        let subtask = PlanTask(title: title, sortOrder: nextOrder, planDay: task.planDay, parent: task)
        withAnimation(.easeOut(duration: 0.22)) {
            modelContext.insert(subtask)
            task.subtasks.append(subtask)
        }
        try? modelContext.save()
        newSubtaskTitle = ""
        isAddingSubtask = false
    }
}
