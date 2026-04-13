import SwiftUI
import SwiftData

/// Identifies a top-level future task for reordering while its row is expanded.
private struct FutureTopLevelDragPayload: Transferable, Codable, Equatable {
    var persistentModelID: PersistentIdentifier

    init(task: FutureTask) {
        self.persistentModelID = task.persistentModelID
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

/// Drop zone between future tasks; highlights when a dragged task hovers.
private struct FutureListInsertionDropZone: View {
    let onDrop: (FutureTopLevelDragPayload) -> Bool

    @State private var isTargeted = false

    var body: some View {
        Color.clear
            .frame(minHeight: 18)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .overlay {
                Capsule()
                    .fill(Color.accentColor)
                    .frame(height: 3)
                    .padding(.horizontal, 20)
                    .opacity(isTargeted ? 1 : 0)
            }
            .animation(.easeInOut(duration: 0.12), value: isTargeted)
            .dropDestination(for: FutureTopLevelDragPayload.self) { items, _ in
                guard let payload = items.first else { return false }
                return onDrop(payload)
            } isTargeted: { isTargeted = $0 }
            .accessibilityLabel("Reorder drop zone")
    }
}

/// Future tasks planning view. Add tasks and subtasks here; move them to Today when ready to work on them.
struct FutureView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(DayStore.self) private var dayStore
    @Environment(StreakStore.self) private var streakStore
    @Query(sort: \FutureTask.sortOrder, order: .forward) private var futureTasks: [FutureTask]
    @State private var newTaskTitle = ""

    /// Called after moving a task to today so the app can switch to the Today view.
    var onMoveToToday: (() -> Void)?

    private var topLevelFutureTasks: [FutureTask] {
        futureTasks.filter(\.isTopLevel).sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                addTaskBar
                if topLevelFutureTasks.isEmpty {
                    emptyState
                } else {
                    taskList
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(.regularMaterial.opacity(0.3))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Future tasks")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Open a task with the chevron to see subtasks. While it's open, drag the card and drop on a line between tasks to put it anywhere in the list. Move to Today when you're ready to start.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var addTaskBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                if newTaskTitle.isEmpty {
                    Text("New future task…")
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
            HStack(spacing: 10) {
                Spacer()
                Button("Add") { addTask() }
                    .buttonStyle(.borderedProminent)
                    .disabled(newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No future tasks", systemImage: "calendar.badge.clock")
        } description: {
            Text("Add a task above to plan work for later. You can add subtasks under each task. Move to Today when you're ready.")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    private var taskList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(topLevelFutureTasks.enumerated()), id: \.element.persistentModelID) { _, task in
                FutureListInsertionDropZone { payload in
                    reorderTopLevelFutureTasks(draggedID: payload.persistentModelID, before: task)
                }
                FutureTaskRow(
                    task: task,
                    onMoveToToday: { moveToToday(task) },
                    onDelete: { deleteTask(task) },
                    onAddSubtask: { addSubtask(to: task, title: $0) }
                )
                .padding(.bottom, 8)
            }
            FutureListInsertionDropZone { payload in
                reorderTopLevelFutureTasks(draggedID: payload.persistentModelID, before: nil)
            }
        }
    }

    /// Inserts the dragged top-level task before `target`, or at the end when `target` is nil; rewrites `sortOrder` 0…n.
    private func reorderTopLevelFutureTasks(draggedID: PersistentIdentifier, before target: FutureTask?) -> Bool {
        guard let dragged = try? modelContext.model(for: draggedID) as? FutureTask,
              dragged.parent == nil else { return false }
        if let target, dragged.persistentModelID == target.persistentModelID { return true }

        var ordered = topLevelFutureTasks.filter { $0.persistentModelID != dragged.persistentModelID }
        if let target {
            guard let idx = ordered.firstIndex(where: { $0.persistentModelID == target.persistentModelID }) else { return false }
            ordered.insert(dragged, at: idx)
        } else {
            ordered.append(dragged)
        }
        for (index, t) in ordered.enumerated() {
            t.sortOrder = index
        }
        try? modelContext.save()
        streakStore.recordUsage()
        return true
    }

    private func addTask() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let nextOrder = (topLevelFutureTasks.map(\.sortOrder).max() ?? -1) + 1
        let task = FutureTask(title: title, sortOrder: nextOrder, createdAt: Date(), parent: nil)
        modelContext.insert(task)
        try? modelContext.save()
        newTaskTitle = ""
        streakStore.recordUsage()
    }

    private func addSubtask(to parent: FutureTask, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let nextOrder = (parent.subtasks.map(\.sortOrder).max() ?? -1) + 1
        let subtask = FutureTask(title: trimmed, sortOrder: nextOrder, createdAt: Date(), parent: parent)
        modelContext.insert(subtask)
        parent.subtasks.append(subtask)
        try? modelContext.save()
        streakStore.recordUsage()
    }

    private func moveToToday(_ futureTask: FutureTask) {
        dayStore.ensureTodayExists(modelContext: modelContext)
        guard let todayPlan = dayStore.fetchDay(for: Date(), modelContext: modelContext) else { return }
        let nextOrder = (todayPlan.tasks.filter { $0.parent == nil }.map(\.sortOrder).max() ?? -1) + 1
        let planTask = PlanTask(
            title: futureTask.title,
            sortOrder: nextOrder,
            planDay: todayPlan,
            parent: nil,
            quadrant: .notImportantNotUrgent
        )
        modelContext.insert(planTask)
        todayPlan.tasks.append(planTask)
        for (index, sub) in futureTask.sortedSubtasks.enumerated() {
            let planSub = PlanTask(
                title: sub.title,
                sortOrder: index,
                planDay: todayPlan,
                parent: planTask,
                quadrant: .notImportantNotUrgent
            )
            modelContext.insert(planSub)
            planTask.subtasks.append(planSub)
        }
        modelContext.delete(futureTask)
        try? modelContext.save()
        streakStore.recordUsage()
        onMoveToToday?()
    }

    private func deleteTask(_ task: FutureTask) {
        modelContext.delete(task)
        try? modelContext.save()
    }
}

// MARK: - Future task row

private struct FutureTaskRow: View {
    @Bindable var task: FutureTask
    let onMoveToToday: () -> Void
    let onDelete: () -> Void
    let onAddSubtask: (String) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var isExpanded = false
    @State private var isAddingSubtask = false
    @State private var newSubtaskTitle = ""
    @State private var isEditingTitle = false
    @State private var editedTitle = ""

    var body: some View {
        Group {
            if isExpanded {
                rowContent
                    .draggable(FutureTopLevelDragPayload(task: task)) {
                        futureTaskDragPreview(task)
                    }
            } else {
                rowContent
            }
        }
    }

    @ViewBuilder
    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    withAnimation(.snappy(duration: 0.22)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                .padding(.top, 2)
                .help(isExpanded ? "Collapse" : "Open to view subtasks and reorder")
                .accessibilityLabel(isExpanded ? "Collapse task" : "Expand task")

                if isEditingTitle {
                    VStack(alignment: .leading, spacing: 8) {
                        ZStack(alignment: .topLeading) {
                            if editedTitle.isEmpty {
                                Text("Task title…")
                                    .font(.body)
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 8)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $editedTitle)
                                .font(.body)
                                .scrollContentBackground(.hidden)
                                .padding(4)
                                .frame(minHeight: 48, maxHeight: 120)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(.quaternary, lineWidth: 1)
                                )
                        }
                        HStack(spacing: 8) {
                            Button("Done") { commitTitleEdit() }
                                .buttonStyle(.borderedProminent)
                            Button("Cancel") { cancelTitleEdit() }
                                .keyboardShortcut(.cancelAction)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(task.title)
                            .font(.body)
                            .lineLimit(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .onTapGesture(count: 2) {
                                editedTitle = task.title
                                isEditingTitle = true
                            }
                        if !isExpanded, !task.subtasks.isEmpty {
                            Text("\(task.subtasks.count)")
                                .font(.caption2)
                                .monospacedDigit()
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.quaternary.opacity(0.75), in: Capsule())
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("\(task.subtasks.count) subtasks")
                        }
                    }
                }
                Button {
                    onMoveToToday()
                } label: {
                    Label("Move to today", systemImage: "arrow.right.circle.fill")
                        .font(.subheadline)
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                if !isEditingTitle {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                    Button {
                        isExpanded = true
                        isAddingSubtask = true
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Add subtask")
                    Button {
                        editedTitle = task.title
                        isEditingTitle = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Edit")
                }
            }
            .padding(14)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            .contextMenu {
                Button {
                    onMoveToToday()
                } label: {
                    Label("Move to today", systemImage: "arrow.right.circle")
                }
                Button {
                    isExpanded = true
                    isAddingSubtask = true
                } label: {
                    Label("Add subtask", systemImage: "plus.circle")
                }
                Button {
                    editedTitle = task.title
                    isEditingTitle = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }

            if isExpanded, !task.subtasks.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(task.sortedSubtasks) { subtask in
                        FutureSubtaskRow(
                            subtask: subtask,
                            onSave: { newTitle in
                                let t = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !t.isEmpty {
                                    subtask.title = t
                                    try? modelContext.save()
                                }
                            },
                            onDelete: { deleteSubtask(subtask) }
                        )
                    }
                }
                .padding(.leading, 24)
                .padding(.top, 8)
                .padding(.bottom, 4)
            }

            if isExpanded, isAddingSubtask {
                VStack(alignment: .leading, spacing: 8) {
                    ZStack(alignment: .topLeading) {
                        if newSubtaskTitle.isEmpty {
                            Text("Subtask title…")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $newSubtaskTitle)
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .padding(4)
                            .frame(minHeight: 48, maxHeight: 120)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(.quaternary, lineWidth: 1)
                            )
                            .onKeyPress { press in
                                guard press.key == .return else { return .ignored }
                                if press.modifiers.contains(.shift) { return .ignored }
                                commitAddSubtask()
                                return .handled
                            }
                    }
                    HStack(spacing: 8) {
                        Button("Add") { commitAddSubtask() }
                        Button("Cancel") {
                            isAddingSubtask = false
                            newSubtaskTitle = ""
                        }
                        .keyboardShortcut(.cancelAction)
                    }
                }
                .padding(.leading, 24)
                .padding(.vertical, 8)
            }
        }
    }

    private func futureTaskDragPreview(_ task: FutureTask) -> some View {
        Text(task.title)
            .font(.subheadline)
            .fontWeight(.medium)
            .lineLimit(2)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: 280, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func commitTitleEdit() {
        let trimmed = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            task.title = trimmed
            try? modelContext.save()
        }
        isEditingTitle = false
        editedTitle = ""
    }

    private func cancelTitleEdit() {
        isEditingTitle = false
        editedTitle = ""
    }

    private func commitAddSubtask() {
        onAddSubtask(newSubtaskTitle)
        newSubtaskTitle = ""
        isAddingSubtask = false
    }

    private func deleteSubtask(_ subtask: FutureTask) {
        modelContext.delete(subtask)
        try? modelContext.save()
    }
}

// MARK: - Future subtask row

private struct FutureSubtaskRow: View {
    let subtask: FutureTask
    let onSave: (String) -> Void
    let onDelete: () -> Void

    @State private var isEditing = false
    @State private var editedTitle = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if isEditing {
                ZStack(alignment: .topLeading) {
                    if editedTitle.isEmpty {
                        Text("Subtask title…")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $editedTitle)
                        .font(.subheadline)
                        .scrollContentBackground(.hidden)
                        .padding(4)
                        .frame(minHeight: 44, maxHeight: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(.quaternary, lineWidth: 1)
                        )
                }
                HStack(spacing: 8) {
                    Button("Done") {
                        onSave(editedTitle)
                        isEditing = false
                        editedTitle = ""
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Cancel") {
                        isEditing = false
                        editedTitle = ""
                    }
                    .keyboardShortcut(.cancelAction)
                }
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "circle.inset.filled")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(subtask.title)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onTapGesture(count: 2) {
                            editedTitle = subtask.title
                            isEditing = true
                        }
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    Button {
                        editedTitle = subtask.title
                        isEditing = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .contextMenu {
            Button {
                editedTitle = subtask.title
                isEditing = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

#Preview {
    FutureView()
        .environment(DayStore())
        .environment(StreakStore())
        .modelContainer(for: [FutureTask.self], inMemory: true)
        .frame(width: 500, height: 400)
}
