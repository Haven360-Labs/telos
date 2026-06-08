import Foundation
import SwiftData
import SwiftUI

/// Links a today `PlanTask` (top-level or subtask) to a project board card.
enum PlanTaskProjectLinking {
    /// Ensures the project has a main board, appends a card to the first column (Todo), and sets `task.linkedKanbanCard`.
    /// No-op if the task is already linked to a card on this project’s main board.
    static func addPlanTaskToProject(
        _ task: PlanTask,
        project: Project,
        modelContext: ModelContext,
        streakStore: StreakStore
    ) {
        guard !project.isArchived else { return }

        ProjectBoardDefaults.ensureDefaultColumns(for: project, modelContext: modelContext)

        let mainColumns = project.kanbanColumns
            .filter { $0.sprint == nil }
            .sorted { $0.sortOrder < $1.sortOrder }
        guard let backlog = mainColumns.first else { return }

        if let existing = task.linkedKanbanCard,
           existing.column?.sprint == nil,
           existing.column?.project?.persistentModelID == project.persistentModelID {
            return
        }

        let trimmed = task.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cardTitle = trimmed.isEmpty ? "Untitled" : trimmed
        let nextOrder = (backlog.cards.map(\.sortOrder).max() ?? -1) + 1
        let card = ProjectKanbanCard(title: cardTitle, body: "", sortOrder: nextOrder, column: backlog)
        modelContext.insert(card)
        backlog.cards.append(card)
        task.linkedKanbanCard = card
        try? modelContext.save()
        streakStore.recordUsage()
    }

    // MARK: - Board card → Today

    /// Project that owns the kanban card linked to this task (main or sprint board).
    static func boardSourceProject(for task: PlanTask) -> Project? {
        guard let card = task.linkedKanbanCard else { return nil }
        return card.column?.project ?? card.column?.sprint?.project
    }

    /// Kanban column title for the linked card, e.g. `"Todo"`, `"In progress"`, `"Completed"`.
    static func boardColumnStatus(for task: PlanTask) -> String? {
        guard let card = task.linkedKanbanCard else { return nil }
        return boardColumnStatus(for: card)
    }

    static func boardColumnStatus(for card: ProjectKanbanCard) -> String? {
        let title = card.column?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return title.isEmpty ? nil : title
    }

    static func boardColumnStatusColor(for status: String) -> Color {
        let normalized = status.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if ProjectBoardDefaults.isCompletedColumnTitle(status) { return .green }
        switch normalized {
        case "in progress", "doing": return .orange
        case "todo", "backlog": return .secondary
        default: return .secondary
        }
    }

    /// Short label for the board the task came from, e.g. `"Acme"` or `"Acme · Sprint 3"`.
    static func boardSourceLabel(for task: PlanTask) -> String? {
        guard let card = task.linkedKanbanCard else { return nil }
        guard let project = card.column?.project ?? card.column?.sprint?.project else { return nil }
        if let sprint = card.column?.sprint {
            return "\(project.name) · \(sprint.title)"
        }
        return project.name
    }

    /// Whether this card already has a non-archived top-level task on today's plan.
    static func isKanbanCardOnToday(
        _ card: ProjectKanbanCard,
        dayStore: DayStore,
        modelContext: ModelContext
    ) -> Bool {
        dayStore.ensureTodayExists(modelContext: modelContext)
        let todayStart = Calendar.current.startOfDay(for: Date())
        guard let planDay = dayStore.fetchDay(for: todayStart, modelContext: modelContext) else { return false }
        return planDay.tasks.contains {
            $0.parent == nil && !$0.isArchived && $0.linkedKanbanCard?.persistentModelID == card.persistentModelID
        }
    }

    /// Creates or returns today's `PlanTask` linked to this board card; syncs title from the card.
    @discardableResult
    static func ensureTodayPlanTask(
        for card: ProjectKanbanCard,
        dayStore: DayStore,
        modelContext: ModelContext,
        streakStore: StreakStore? = nil
    ) -> PlanTask {
        dayStore.ensureTodayExists(modelContext: modelContext)
        let todayStart = Calendar.current.startOfDay(for: Date())
        let planDay = dayStore.fetchDay(for: todayStart, modelContext: modelContext)
            ?? dayStore.ensureDayExists(for: todayStart, modelContext: modelContext)
        if let existing = planDay.tasks.first(where: {
            $0.parent == nil && !$0.isArchived && $0.linkedKanbanCard?.persistentModelID == card.persistentModelID
        }) {
            syncTodayPlanTaskTitle(planTask: existing, card: card, modelContext: modelContext)
            return existing
        }
        let nextOrder = (planDay.tasks.filter { $0.parent == nil }.map(\.sortOrder).max() ?? -1) + 1
        let title = card.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled" : card.title
        let task = PlanTask(
            title: title,
            sortOrder: nextOrder,
            planDay: planDay,
            parent: nil,
            quadrant: AppTaskSettings.defaultQuadrant,
            linkedKanbanCard: card
        )
        modelContext.insert(task)
        planDay.tasks.append(task)
        try? modelContext.save()
        streakStore?.recordUsage()
        return task
    }

    static func syncTodayPlanTaskTitle(
        planTask: PlanTask,
        card: ProjectKanbanCard,
        modelContext: ModelContext
    ) {
        let t = card.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled" : card.title
        guard planTask.title != t else { return }
        planTask.title = t
        try? modelContext.save()
    }

    static func syncTodayPlanTaskTitles(
        for card: ProjectKanbanCard,
        dayStore: DayStore,
        modelContext: ModelContext
    ) {
        let todayStart = Calendar.current.startOfDay(for: Date())
        guard let day = dayStore.fetchDay(for: todayStart, modelContext: modelContext) else { return }
        for task in day.tasks where task.parent == nil && task.linkedKanbanCard?.persistentModelID == card.persistentModelID {
            syncTodayPlanTaskTitle(planTask: task, card: card, modelContext: modelContext)
        }
    }

    // MARK: - Completion sync (board ↔ Today)

    private static func boardColumns(for card: ProjectKanbanCard) -> [ProjectKanbanColumn] {
        guard let column = card.column else { return [] }
        if let sprint = column.sprint {
            return sprint.kanbanColumns.sorted { $0.sortOrder < $1.sortOrder }
        }
        if let project = column.project {
            return project.kanbanColumns
                .filter { $0.sprint == nil }
                .sorted { $0.sortOrder < $1.sortOrder }
        }
        return []
    }

    private static func completedColumn(in columns: [ProjectKanbanColumn]) -> ProjectKanbanColumn? {
        columns.first { ProjectBoardDefaults.isCompletedColumnTitle($0.title) }
    }

    private static func inProgressColumn(in columns: [ProjectKanbanColumn]) -> ProjectKanbanColumn? {
        columns.first { ProjectBoardDefaults.isInProgressColumnTitle($0.title) }
            ?? columns.first { !ProjectBoardDefaults.isCompletedColumnTitle($0.title) }
    }

    private static func todayLinkedPlanTask(
        for card: ProjectKanbanCard,
        dayStore: DayStore,
        modelContext: ModelContext
    ) -> PlanTask? {
        let todayStart = Calendar.current.startOfDay(for: Date())
        guard let planDay = dayStore.fetchDay(for: todayStart, modelContext: modelContext) else { return nil }
        return planDay.tasks.first {
            $0.parent == nil && !$0.isArchived && $0.linkedKanbanCard?.persistentModelID == card.persistentModelID
        }
    }

    /// Keeps today's linked plan task aligned when a board card changes column.
    static func syncTodayFromBoardMove(
        card: ProjectKanbanCard,
        from oldColumn: ProjectKanbanColumn?,
        to targetColumn: ProjectKanbanColumn,
        modelContext: ModelContext,
        timerStore: TimerStore? = nil
    ) {
        let dayStore = DayStore()

        if ProjectBoardDefaults.isCompletedColumnTitle(targetColumn.title) {
            let task = ensureTodayPlanTask(for: card, dayStore: dayStore, modelContext: modelContext)
            timerStore?.stopIfActive(task: task, modelContext: modelContext)
            guard !task.isCompleted else { return }
            task.isCompleted = true
            try? modelContext.save()
            return
        }

        if ProjectBoardDefaults.isInProgressColumnTitle(targetColumn.title) {
            let task = ensureTodayPlanTask(for: card, dayStore: dayStore, modelContext: modelContext)
            guard task.isCompleted else { return }
            task.isCompleted = false
            try? modelContext.save()
            return
        }

        let leavingCompleted = oldColumn.map { ProjectBoardDefaults.isCompletedColumnTitle($0.title) } ?? false
        guard leavingCompleted,
              let task = todayLinkedPlanTask(for: card, dayStore: dayStore, modelContext: modelContext),
              task.isCompleted else { return }
        task.isCompleted = false
        try? modelContext.save()
    }

    /// Moves the linked board card when a today task is completed or reopened.
    static func syncBoardFromTodayCompletion(
        task: PlanTask,
        modelContext: ModelContext,
        timerStore: TimerStore? = nil
    ) {
        guard task.parent == nil, let card = task.linkedKanbanCard else { return }
        let columns = boardColumns(for: card)
        guard !columns.isEmpty else { return }

        if task.isCompleted {
            timerStore?.stopIfActive(task: task, modelContext: modelContext)
            guard let completed = completedColumn(in: columns),
                  card.column?.persistentModelID != completed.persistentModelID else { return }
            KanbanBoardDragSupport.drop(
                dragged: card,
                targetColumn: completed,
                before: nil,
                modelContext: modelContext,
                timerStore: timerStore
            )
            return
        }

        guard let current = card.column,
              ProjectBoardDefaults.isCompletedColumnTitle(current.title),
              let inProgress = inProgressColumn(in: columns),
              current.persistentModelID != inProgress.persistentModelID else { return }
        KanbanBoardDragSupport.drop(
            dragged: card,
            targetColumn: inProgress,
            before: nil,
            modelContext: modelContext,
            timerStore: timerStore
        )
    }
}
