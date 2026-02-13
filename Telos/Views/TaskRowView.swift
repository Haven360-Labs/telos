import SwiftUI
import SwiftData

struct TaskRowView: View {
    private static let countdownDurations = [15, 30, 45, 60, 75, 90]

    @Bindable var task: PlanTask
    var timerStore: TimerStore
    @Environment(\.modelContext) private var modelContext
    @Environment(StreakStore.self) private var streakStore
    @State private var isAddingSubtask = false
    @State private var newSubtaskTitle = ""
    @State private var isEditingTitle = false
    @State private var editedTitle = ""
    @FocusState private var isTitleFieldFocused: Bool
    @State private var showCompleteSubtasksAlert = false
    @State private var showCustomTimerSheet = false
    @State private var showScheduledDatePopover = false

    private var hasIncompleteSubtasks: Bool {
        !task.subtasks.isEmpty && !task.subtasks.allSatisfy(\.isCompleted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                Button {
                    if !task.isCompleted && hasIncompleteSubtasks {
                        showCompleteSubtasksAlert = true
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            task.isCompleted.toggle()
                        }
                        try? modelContext.save()
                    }
                } label: {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(task.isCompleted ? .green : .secondary)
                }
                .buttonStyle(.plain)

                if isEditingTitle {
                    TextField("Task title", text: $editedTitle)
                        .textFieldStyle(.roundedBorder)
                        .focused($isTitleFieldFocused)
                        .onSubmit { commitTitleEdit() }
                        .onExitCommand { cancelTitleEdit() }
                } else {
                    Text(task.title)
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)
                    Button {
                        editedTitle = task.title
                        isEditingTitle = true
                        isTitleFieldFocused = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                if !isEditingTitle && task.parent == nil {
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

                if !isEditingTitle {
                    if task.parent == nil && task.quadrant == .importantNotUrgent {
                        scheduledDateLabel
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

                    if timerStore.isActive(task: task) {
                        Image(systemName: "timer")
                            .foregroundStyle(.orange)
                    } else {
                        Menu {
                            Button {
                                guard !task.isCompleted else { return }
                                timerStore.startCountUp(task: task, modelContext: modelContext)
                                streakStore.recordUsage()
                            } label: {
                                Label("Count up", systemImage: "arrow.up.circle")
                            }
                            .disabled(task.isCompleted)
                            Section("Countdown") {
                                ForEach(TaskRowView.countdownDurations, id: \.self) { minutes in
                                    Button("\(minutes) min") {
                                        guard !task.isCompleted else { return }
                                        timerStore.startCountdown(task: task, durationMinutes: minutes, modelContext: modelContext)
                                        streakStore.recordUsage()
                                    }
                                    .disabled(task.isCompleted)
                                }
                                Button("Custom…") {
                                    guard !task.isCompleted else { return }
                                    showCustomTimerSheet = true
                                }
                                .disabled(task.isCompleted)
                            }
                        } label: {
                            Image(systemName: "play.circle")
                                .foregroundStyle(task.isCompleted ? Color.secondary.opacity(0.5) : .secondary)
                        }
                        .menuStyle(.borderlessButton)
                        .disabled(task.isCompleted)
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
            }
            .padding(.vertical, 4)
            .contextMenu {
                Button {
                    editedTitle = task.title
                    isEditingTitle = true
                    isTitleFieldFocused = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    deleteTask()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                Divider()
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
        .sheet(isPresented: $showCustomTimerSheet) {
            CustomTimerSheet(
                onStart: { totalMinutes in
                    timerStore.startCountdown(task: task, durationMinutes: totalMinutes, modelContext: modelContext)
                    streakStore.recordUsage()
                    showCustomTimerSheet = false
                },
                onCancel: { showCustomTimerSheet = false }
            )
            .frame(minWidth: 280, minHeight: 180)
        }
        .alert("Complete subtasks first", isPresented: $showCompleteSubtasksAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Complete all subtasks before marking this task as done.")
        }
    }

    @ViewBuilder
    private var scheduledDateLabel: some View {
        Button {
            showScheduledDatePopover = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.caption2)
                if let date = task.scheduledDate {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                } else {
                    Text("Set date")
                        .font(.caption)
                }
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.quaternary.opacity(0.8), in: RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showScheduledDatePopover, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Work on date")
                    .font(.subheadline)
                    .fontWeight(.medium)
                DatePicker(
                    "Date",
                    selection: Binding(
                        get: { task.scheduledDate ?? Date() },
                        set: { task.scheduledDate = $0 }
                    ),
                    displayedComponents: .date
                )
                .labelsHidden()
                if task.scheduledDate != nil {
                    Button("Clear date") {
                        task.scheduledDate = nil
                        try? modelContext.save()
                        showScheduledDatePopover = false
                    }
                    .foregroundStyle(.red)
                }
            }
            .padding(16)
            .frame(width: 220)
            .onChange(of: task.scheduledDate) { _, _ in
                try? modelContext.save()
            }
        }
    }

    private func commitTitleEdit() {
        let trimmed = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            task.title = trimmed
            try? modelContext.save()
            streakStore.recordUsage()
        }
        isEditingTitle = false
        isTitleFieldFocused = false
    }

    private func cancelTitleEdit() {
        isEditingTitle = false
        isTitleFieldFocused = false
    }

    private func deleteTask() {
        if timerStore.isActive(task: task) {
            timerStore.stopAndRecord(modelContext: modelContext)
        }
        modelContext.delete(task)
        try? modelContext.save()
        streakStore.recordUsage()
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

// MARK: - Custom timer sheet
struct CustomTimerSheet: View {
    var onStart: (Int) -> Void
    var onCancel: () -> Void

    @State private var hours: Int = 0
    @State private var minutes: Int = 30

    private var totalMinutes: Int { hours * 60 + minutes }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Custom countdown")
                .font(.headline)
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                HStack(spacing: 6) {
                    Text("Hours")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Picker("Hours", selection: $hours) {
                        ForEach(0 ..< 25, id: \.self) { h in
                            Text("\(h)").tag(h)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 60)
                }
                HStack(spacing: 6) {
                    Text("Min")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Picker("Minutes", selection: $minutes) {
                        ForEach(0 ..< 60, id: \.self) { m in
                            Text("\(m)").tag(m)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 60)
                }
            }
            Text(totalMinutes == 0 ? "Set duration" : "Total: \(hours):\(String(format: "%02d", minutes))")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Button("Cancel") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Start") {
                    guard totalMinutes > 0 else { return }
                    onStart(totalMinutes)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(totalMinutes <= 0)
            }
        }
        .padding(20)
    }
}
