import SwiftData

/// Links a today `PlanTask` (top-level or subtask) to a project board card.
enum PlanTaskProjectLinking {
    /// Ensures the project has a main board, appends a card to the first column (Backlog), and sets `task.linkedKanbanCard`.
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
}
