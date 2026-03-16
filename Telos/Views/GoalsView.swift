import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Payload for drag-and-drop of goals between weeks or reorder within a week.
private struct GoalDragPayload: Transferable, Codable {
    let sourceWeek: Int
    let sourceIndex: Int

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

/// Plan monthly and weekly goals. Shows the selected month with Week 1–4 sections.
struct GoalsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(DayStore.self) private var dayStore
    @Query(sort: \PlanGoal.sortOrder, order: .forward) private var allGoals: [PlanGoal]

    private let calendar = Calendar.current
    private let weekNumbers = [1, 2, 3, 4]

    /// Called after making a goal into a today task so the app can switch to Today (optional).
    var onMakeTodayTask: (() -> Void)?

    private static func currentMonthStart(calendar: Calendar) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
    }

    @State private var selectedMonthStart: Date = GoalsView.currentMonthStart(calendar: .current)

    private var isViewingCurrentMonth: Bool {
        calendar.isDate(selectedMonthStart, inSameDayAs: Self.currentMonthStart(calendar: calendar))
    }

    private func goals(forWeek week: Int) -> [PlanGoal] {
        allGoals.filter { goal in
            calendar.isDate(goal.month, inSameDayAs: selectedMonthStart) && goal.weekNumber == week
        }.sorted { g1, g2 in
            if g1.isCompleted != g2.isCompleted { return !g1.isCompleted }
            return g1.sortOrder < g2.sortOrder
        }
    }

    private var monthlyGoals: [PlanGoal] {
        goals(forWeek: 0)
    }

    /// When viewing the current month, the week (1–4) that contains today; nil otherwise.
    private var currentWeekInSelectedMonth: Int? {
        guard calendar.isDate(selectedMonthStart, inSameDayAs: Self.currentMonthStart(calendar: calendar)) else { return nil }
        let dayOfMonth = calendar.component(.day, from: Date())
        let weekNum = ((dayOfMonth - 1) / 7) + 1
        return min(max(weekNum, 1), 4)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                overallGoalsSection
                ForEach(weekNumbers, id: \.self) { week in
                    weekSection(week: week)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(.regularMaterial.opacity(0.3))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button {
                    selectedMonthStart = calendar.date(byAdding: .month, value: -1, to: selectedMonthStart) ?? selectedMonthStart
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.bordered)
                Text(selectedMonthFormatted)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .frame(minWidth: 160, alignment: .center)
                Button {
                    selectedMonthStart = calendar.date(byAdding: .month, value: 1, to: selectedMonthStart) ?? selectedMonthStart
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.bordered)
                if !isViewingCurrentMonth {
                    Button("This month") {
                        selectedMonthStart = Self.currentMonthStart(calendar: calendar)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            Text("Set overall goals for the month, then goals for each week.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var overallGoalsSection: some View {
        WeekGoalsSection(
            weekNumber: 0,
            sectionTitle: "Overall goals",
            isCurrentWeek: false,
            goals: monthlyGoals,
            onAdd: { title in addGoal(title: title, week: 0) },
            onSave: { goal, newTitle in saveGoal(goal, title: newTitle) },
            onDelete: { deleteGoal($0) },
            onMakeTodayTask: { makeGoalTodayTask($0) },
            onComplete: { toggleComplete($0) },
            onMoveToNextMonth: { moveGoalToNextMonth($0) },
            onMoveGoal: { moveGoal(fromSourceWeek: $0, fromSourceIndex: $1, toTargetWeek: $2, toTargetIndex: $3) }
        )
    }

    private var selectedMonthFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedMonthStart)
    }

    private func weekSection(week: Int) -> some View {
        WeekGoalsSection(
            weekNumber: week,
            sectionTitle: nil,
            isCurrentWeek: currentWeekInSelectedMonth == week,
            goals: goals(forWeek: week),
            onAdd: { title in addGoal(title: title, week: week) },
            onSave: { goal, newTitle in saveGoal(goal, title: newTitle) },
            onDelete: { deleteGoal($0) },
            onMakeTodayTask: { makeGoalTodayTask($0) },
            onComplete: { toggleComplete($0) },
            onMoveToNextMonth: { moveGoalToNextMonth($0) },
            onMoveGoal: { moveGoal(fromSourceWeek: $0, fromSourceIndex: $1, toTargetWeek: $2, toTargetIndex: $3) }
        )
    }

    private func addGoal(title: String, week: Int) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let goalsInWeek = goals(forWeek: week)
        let nextOrder = (goalsInWeek.map(\.sortOrder).max() ?? -1) + 1
        let goal = PlanGoal(title: trimmed, sortOrder: nextOrder, createdAt: Date(), month: selectedMonthStart, weekNumber: week)
        modelContext.insert(goal)
        try? modelContext.save()
    }

    private func saveGoal(_ goal: PlanGoal, title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        goal.title = trimmed
        try? modelContext.save()
    }

    private func deleteGoal(_ goal: PlanGoal) {
        modelContext.delete(goal)
        try? modelContext.save()
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
        onMakeTodayTask?()
    }

    private func toggleComplete(_ goal: PlanGoal) {
        goal.isCompleted.toggle()
        try? modelContext.save()
    }

    private func moveGoalToNextMonth(_ goal: PlanGoal) {
        goal.month = calendar.date(byAdding: .month, value: 1, to: goal.month) ?? goal.month
        try? modelContext.save()
    }

    /// Move or reorder a goal: from (sourceWeek, sourceIndex) to (targetWeek, targetIndex).
    private func moveGoal(fromSourceWeek sourceWeek: Int, fromSourceIndex sourceIndex: Int, toTargetWeek targetWeek: Int, toTargetIndex targetIndex: Int) {
        let listFrom = goals(forWeek: sourceWeek)
        let listTo = goals(forWeek: targetWeek)
        guard sourceIndex >= 0, sourceIndex < listFrom.count else { return }
        let goal = listFrom[sourceIndex]
        if sourceWeek == targetWeek && sourceIndex == targetIndex { return }

        if sourceWeek == targetWeek {
            var reordered = listFrom
            reordered.remove(at: sourceIndex)
            let toIdx = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
            let insertIndex = min(max(toIdx, 0), reordered.count)
            reordered.insert(goal, at: insertIndex)
            for (i, g) in reordered.enumerated() {
                g.sortOrder = i
            }
        } else {
            goal.weekNumber = targetWeek
            for (i, g) in listFrom.filter({ $0.persistentModelID != goal.persistentModelID }).enumerated() {
                g.sortOrder = i
            }
            let insertOrder = min(max(targetIndex, 0), listTo.count)
            for g in listTo {
                if g.sortOrder >= insertOrder {
                    g.sortOrder += 1
                }
            }
            goal.sortOrder = insertOrder
        }
        try? modelContext.save()
    }
}

// MARK: - Week goals section

private struct WeekGoalsSection: View {
    let weekNumber: Int
    /// If nil, shows "Week N"; use "Overall goals" for month-level goals.
    var sectionTitle: String? = nil
    /// True when this week is the current week in the (current) month.
    var isCurrentWeek: Bool = false
    let goals: [PlanGoal]
    let onAdd: (String) -> Void
    let onSave: (PlanGoal, String) -> Void
    let onDelete: (PlanGoal) -> Void
    let onMakeTodayTask: (PlanGoal) -> Void
    let onComplete: (PlanGoal) -> Void
    let onMoveToNextMonth: (PlanGoal) -> Void
    let onMoveGoal: (Int, Int, Int, Int) -> Void

    @State private var newGoalTitle = ""

    private var title: String {
        sectionTitle ?? "Week \(weekNumber)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: weekNumber == 0 ? "star.circle.fill" : "circle.hexagongrid.fill")
                    .font(.body)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.headline)
                if isCurrentWeek {
                    Text("Current week")
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.tint.opacity(0.2), in: Capsule())
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(goals.enumerated()), id: \.element.id) { index, goal in
                    GoalRowView(
                        goal: goal,
                        onSave: { onSave(goal, $0) },
                        onDelete: { onDelete(goal) },
                        onMakeTodayTask: { onMakeTodayTask(goal) },
                        onComplete: { onComplete(goal) },
                        onMoveToNextMonth: { onMoveToNextMonth(goal) }
                    )
                    .draggable(GoalDragPayload(sourceWeek: weekNumber, sourceIndex: index))
                    .dropDestination(for: GoalDragPayload.self) { payloads, _ in
                        guard let payload = payloads.first else { return false }
                        let toIdx = payload.sourceWeek == weekNumber && payload.sourceIndex < index ? index - 1 : index
                        if payload.sourceWeek == weekNumber && payload.sourceIndex == toIdx { return false }
                        onMoveGoal(payload.sourceWeek, payload.sourceIndex, weekNumber, toIdx)
                        return true
                    } isTargeted: { _ in }
                }
                addGoalBar
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .dropDestination(for: GoalDragPayload.self) { payloads, _ in
                guard let payload = payloads.first else { return false }
                let toIdx = goals.count
                if payload.sourceWeek == weekNumber && payload.sourceIndex == toIdx { return false }
                onMoveGoal(payload.sourceWeek, payload.sourceIndex, weekNumber, toIdx)
                return true
            } isTargeted: { _ in }
        }
    }

    private var addGoalBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                if newGoalTitle.isEmpty {
                    Text(weekNumber == 0 ? "Add overall goal for the month…" : "Add goal for Week \(weekNumber)…")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $newGoalTitle)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(4)
                    .frame(minHeight: 44, maxHeight: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(.quaternary, lineWidth: 1)
                    )
                    .onKeyPress { press in
                        guard press.key == .return else { return .ignored }
                        if press.modifiers.contains(.shift) { return .ignored }
                        commitAdd()
                        return .handled
                    }
            }
            HStack(spacing: 8) {
                Button("Add") {
                    commitAdd()
                }
                .buttonStyle(.borderedProminent)
                .disabled(newGoalTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func commitAdd() {
        onAdd(newGoalTitle)
        newGoalTitle = ""
    }
}

// MARK: - Goal row (display + edit)

private struct GoalRowView: View {
    let goal: PlanGoal
    let onSave: (String) -> Void
    let onDelete: () -> Void
    let onMakeTodayTask: () -> Void
    let onComplete: () -> Void
    let onMoveToNextMonth: () -> Void

    @State private var isEditing = false
    @State private var editedTitle = ""

    var body: some View {
        Group {
            if isEditing {
                VStack(alignment: .leading, spacing: 8) {
                    ZStack(alignment: .topLeading) {
                        if editedTitle.isEmpty {
                            Text("Goal…")
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
                            .frame(minHeight: 44, maxHeight: 100)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(.quaternary, lineWidth: 1)
                            )
                    }
                    HStack(spacing: 8) {
                        Button("Done") {
                            commitEdit()
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Cancel") {
                            isEditing = false
                            editedTitle = ""
                        }
                        .keyboardShortcut(.cancelAction)
                    }
                }
                .padding(12)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            } else {
                HStack(spacing: 10) {
                    Button {
                        onComplete()
                    } label: {
                        Image(systemName: goal.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.body)
                            .foregroundStyle(goal.isCompleted ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(goal.isCompleted ? "Mark incomplete" : "Complete")
                    Text(goal.title)
                        .font(.body)
                        .strikethrough(goal.isCompleted)
                        .foregroundStyle(goal.isCompleted ? .secondary : .primary)
                        .lineLimit(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onTapGesture(count: 2) {
                            editedTitle = goal.title
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
                        editedTitle = goal.title
                        isEditing = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                .contextMenu {
                    Button {
                        onMakeTodayTask()
                    } label: {
                        Label("Make today task", systemImage: "sun.max")
                    }
                    Button {
                        onComplete()
                    } label: {
                        Label(goal.isCompleted ? "Mark incomplete" : "Complete", systemImage: goal.isCompleted ? "circle" : "checkmark.circle")
                    }
                    Button {
                        onMoveToNextMonth()
                    } label: {
                        Label("Move to next month", systemImage: "arrow.right.circle")
                    }
                    Divider()
                    Button {
                        editedTitle = goal.title
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
    }

    private func commitEdit() {
        let trimmed = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            onSave(trimmed)
        }
        isEditing = false
        editedTitle = ""
    }
}

#Preview {
    GoalsView()
        .environment(DayStore())
        .modelContainer(for: [PlanGoal.self, PlanDay.self, PlanTask.self], inMemory: true)
        .frame(width: 500, height: 560)
}
