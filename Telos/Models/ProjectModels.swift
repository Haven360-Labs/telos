import Foundation
import SwiftData

// MARK: - Project (root)

/// Container for project-scoped notes, board, sprints, retros, timeline, and documents.
@Model
final class Project {
    var name: String
    var createdAt: Date
    /// Archived projects are hidden from the main list unless “Show archived” is on.
    var isArchived: Bool = false
    var archivedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \PlanNote.project)
    var notes: [PlanNote] = []

    @Relationship(deleteRule: .cascade, inverse: \ProjectKanbanColumn.project)
    var kanbanColumns: [ProjectKanbanColumn] = []

    @Relationship(deleteRule: .cascade, inverse: \ProjectSprint.project)
    var sprints: [ProjectSprint] = []

    @Relationship(deleteRule: .cascade, inverse: \ProjectRetrospective.project)
    var retrospectives: [ProjectRetrospective] = []

    @Relationship(deleteRule: .cascade, inverse: \ProjectTimelineEvent.project)
    var timelineEvents: [ProjectTimelineEvent] = []

    @Relationship(deleteRule: .cascade, inverse: \ProjectDocument.project)
    var documents: [ProjectDocument] = []

    init(name: String, createdAt: Date = Date(), isArchived: Bool = false, archivedAt: Date? = nil) {
        self.name = name
        self.createdAt = createdAt
        self.isArchived = isArchived
        self.archivedAt = archivedAt
    }
}

// MARK: - Kanban

@Model
final class ProjectKanbanColumn {
    var title: String
    var sortOrder: Int
    var project: Project?
    /// When set, this column belongs to the sprint’s board; when `nil`, it belongs to the project’s main board.
    var sprint: ProjectSprint?

    @Relationship(deleteRule: .cascade, inverse: \ProjectKanbanCard.column)
    var cards: [ProjectKanbanCard] = []

    init(title: String, sortOrder: Int = 0, project: Project? = nil, sprint: ProjectSprint? = nil) {
        self.title = title
        self.sortOrder = sortOrder
        self.project = project
        self.sprint = sprint
    }

    var sortedCards: [ProjectKanbanCard] {
        cards.sorted { $0.sortOrder < $1.sortOrder }
    }
}

@Model
final class ProjectKanbanCard {
    var title: String
    var body: String
    var sortOrder: Int
    var column: ProjectKanbanColumn?

    init(title: String, body: String = "", sortOrder: Int = 0, column: ProjectKanbanColumn? = nil) {
        self.title = title
        self.body = body
        self.sortOrder = sortOrder
        self.column = column
    }
}

// MARK: - Sprint

@Model
final class ProjectSprint {
    var title: String
    var startDate: Date
    var endDate: Date
    var notes: String
    var project: Project?
    /// Archived sprints are hidden from the main sprint list unless “Show archived” is on.
    var isArchived: Bool = false
    var archivedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \ProjectKanbanColumn.sprint)
    var kanbanColumns: [ProjectKanbanColumn] = []

    @Relationship(deleteRule: .nullify, inverse: \ProjectRetrospective.sprint)
    var retrospectives: [ProjectRetrospective] = []

    init(title: String, startDate: Date, endDate: Date, notes: String = "", project: Project? = nil, isArchived: Bool = false, archivedAt: Date? = nil) {
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.project = project
        self.isArchived = isArchived
        self.archivedAt = archivedAt
    }
}

// MARK: - Project retrospective

@Model
final class ProjectRetrospective {
    var notes: String
    var createdAt: Date
    var project: Project?
    var sprint: ProjectSprint?

    init(notes: String = "", createdAt: Date = Date(), project: Project? = nil, sprint: ProjectSprint? = nil) {
        self.notes = notes
        self.createdAt = createdAt
        self.project = project
        self.sprint = sprint
    }
}

// MARK: - Timeline

@Model
final class ProjectTimelineEvent {
    var title: String
    var startDate: Date
    var endDate: Date?
    var detail: String
    var sortOrder: Int
    var project: Project?

    init(
        title: String,
        startDate: Date,
        endDate: Date? = nil,
        detail: String = "",
        sortOrder: Int = 0,
        project: Project? = nil
    ) {
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.detail = detail
        self.sortOrder = sortOrder
        self.project = project
    }
}

// MARK: - Document reference

@Model
final class ProjectDocument {
    var displayName: String
    var bookmarkData: Data
    var addedAt: Date
    var project: Project?

    init(displayName: String, bookmarkData: Data, addedAt: Date = Date(), project: Project? = nil) {
        self.displayName = displayName
        self.bookmarkData = bookmarkData
        self.addedAt = addedAt
        self.project = project
    }
}

// MARK: - Defaults

enum ProjectBoardDefaults {
    static let columnTitles = ["Backlog", "Doing", "Done"]

    static func ensureDefaultColumns(for project: Project, modelContext: ModelContext) {
        let mainBoard = project.kanbanColumns.filter { $0.sprint == nil }
        guard mainBoard.isEmpty else { return }
        for (index, title) in columnTitles.enumerated() {
            let col = ProjectKanbanColumn(title: title, sortOrder: index, project: project, sprint: nil)
            modelContext.insert(col)
            project.kanbanColumns.append(col)
        }
    }

    /// Creates default Backlog / Doing / Done columns for a sprint’s board (tied to the same project).
    static func ensureDefaultColumns(for sprint: ProjectSprint, modelContext: ModelContext) {
        guard sprint.kanbanColumns.isEmpty, let project = sprint.project else { return }
        for (index, title) in columnTitles.enumerated() {
            let col = ProjectKanbanColumn(title: title, sortOrder: index, project: project, sprint: sprint)
            modelContext.insert(col)
        }
    }
}
