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

    @Relationship(deleteRule: .cascade, inverse: \ProjectTheme.project)
    var themes: [ProjectTheme] = []

    @Relationship(deleteRule: .cascade, inverse: \ProjectEpic.project)
    var epics: [ProjectEpic] = []

    @Relationship(deleteRule: .cascade, inverse: \ProjectRoadmapItem.project)
    var roadmapItems: [ProjectRoadmapItem] = []

    @Relationship(deleteRule: .cascade, inverse: \ProjectDecision.project)
    var decisions: [ProjectDecision] = []

    @Relationship(deleteRule: .cascade, inverse: \ProjectMilestone.project)
    var milestones: [ProjectMilestone] = []

    @Relationship(deleteRule: .cascade, inverse: \ProjectRelease.project)
    var releases: [ProjectRelease] = []

    @Relationship(deleteRule: .cascade, inverse: \ProjectIssue.project)
    var issues: [ProjectIssue] = []

    @Relationship(deleteRule: .cascade, inverse: \ProjectRisk.project)
    var risks: [ProjectRisk] = []

    @Relationship(deleteRule: .cascade, inverse: \ProjectTestSuite.project)
    var testSuites: [ProjectTestSuite] = []

    @Relationship(deleteRule: .cascade, inverse: \ProjectChangelogEntry.project)
    var changelogEntries: [ProjectChangelogEntry] = []

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
    var epic: ProjectEpic?
    var milestone: ProjectMilestone?
    /// RICE inputs (1–10); 0 means unset in UI.
    var riceReach: Int = 0
    var riceImpact: Int = 0
    var riceConfidence: Int = 0
    var riceEffort: Int = 0
    /// WSJF inputs; 0 means unset.
    var wsjfCostOfDelay: Double = 0
    var wsjfJobSize: Double = 0

    @Relationship(deleteRule: .cascade, inverse: \ProjectKanbanChecklistItem.card)
    var checklistItems: [ProjectKanbanChecklistItem] = []

    @Relationship(deleteRule: .nullify, inverse: \ProjectIssue.kanbanCard)
    var linkedIssues: [ProjectIssue] = []

    init(title: String, body: String = "", sortOrder: Int = 0, column: ProjectKanbanColumn? = nil, epic: ProjectEpic? = nil, milestone: ProjectMilestone? = nil) {
        self.title = title
        self.body = body
        self.sortOrder = sortOrder
        self.column = column
        self.epic = epic
        self.milestone = milestone
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

// MARK: - Strategy (themes, epics, roadmap, decisions)

@Model
final class ProjectTheme {
    var title: String
    var sortOrder: Int
    var project: Project?

    @Relationship(deleteRule: .cascade, inverse: \ProjectEpic.theme)
    var epics: [ProjectEpic] = []

    init(title: String, sortOrder: Int = 0, project: Project? = nil) {
        self.title = title
        self.sortOrder = sortOrder
        self.project = project
    }
}

@Model
final class ProjectEpic {
    var title: String
    var sortOrder: Int
    var project: Project?
    var theme: ProjectTheme?

    init(title: String, sortOrder: Int = 0, project: Project? = nil, theme: ProjectTheme? = nil) {
        self.title = title
        self.sortOrder = sortOrder
        self.project = project
        self.theme = theme
    }
}

@Model
final class ProjectRoadmapItem {
    var title: String
    var targetStart: Date
    var targetEnd: Date?
    var notes: String
    var sortOrder: Int
    var project: Project?
    var epic: ProjectEpic?

    @Relationship(deleteRule: .nullify, inverse: \ProjectMilestone.roadmapItem)
    var milestones: [ProjectMilestone] = []

    init(
        title: String,
        targetStart: Date,
        targetEnd: Date? = nil,
        notes: String = "",
        sortOrder: Int = 0,
        project: Project? = nil,
        epic: ProjectEpic? = nil
    ) {
        self.title = title
        self.targetStart = targetStart
        self.targetEnd = targetEnd
        self.notes = notes
        self.sortOrder = sortOrder
        self.project = project
        self.epic = epic
    }
}

@Model
final class ProjectDecision {
    var title: String
    var decidedAt: Date
    var context: String
    var decision: String
    var rationale: String
    var project: Project?

    init(
        title: String,
        decidedAt: Date = Date(),
        context: String = "",
        decision: String = "",
        rationale: String = "",
        project: Project? = nil
    ) {
        self.title = title
        self.decidedAt = decidedAt
        self.context = context
        self.decision = decision
        self.rationale = rationale
        self.project = project
    }
}

// MARK: - Work breakdown (milestones, releases, card checklist)

@Model
final class ProjectKanbanChecklistItem {
    var title: String
    var isDone: Bool = false
    var sortOrder: Int
    var card: ProjectKanbanCard?

    init(title: String, isDone: Bool = false, sortOrder: Int = 0, card: ProjectKanbanCard? = nil) {
        self.title = title
        self.isDone = isDone
        self.sortOrder = sortOrder
        self.card = card
    }
}

@Model
final class ProjectMilestone {
    var title: String
    var targetDate: Date
    var isCompleted: Bool = false
    var sortOrder: Int
    var project: Project?
    var epic: ProjectEpic?
    var roadmapItem: ProjectRoadmapItem?

    @Relationship(deleteRule: .nullify, inverse: \ProjectIssue.milestone)
    var linkedIssues: [ProjectIssue] = []

    @Relationship(deleteRule: .nullify, inverse: \ProjectKanbanCard.milestone)
    var linkedKanbanCards: [ProjectKanbanCard] = []

    init(
        title: String,
        targetDate: Date,
        isCompleted: Bool = false,
        sortOrder: Int = 0,
        project: Project? = nil,
        epic: ProjectEpic? = nil,
        roadmapItem: ProjectRoadmapItem? = nil
    ) {
        self.title = title
        self.targetDate = targetDate
        self.isCompleted = isCompleted
        self.sortOrder = sortOrder
        self.project = project
        self.epic = epic
        self.roadmapItem = roadmapItem
    }
}

@Model
final class ProjectRelease {
    var version: String
    var targetDate: Date?
    var status: String
    var project: Project?

    @Relationship(deleteRule: .cascade, inverse: \ReleaseChecklistItem.release)
    var checklistItems: [ReleaseChecklistItem] = []

    @Relationship(deleteRule: .nullify, inverse: \ProjectChangelogEntry.release)
    var changelogEntries: [ProjectChangelogEntry] = []

    init(version: String, targetDate: Date? = nil, status: String = "planned", project: Project? = nil) {
        self.version = version
        self.targetDate = targetDate
        self.status = status
        self.project = project
    }
}

@Model
final class ReleaseChecklistItem {
    var title: String
    var isDone: Bool = false
    var sortOrder: Int
    var release: ProjectRelease?

    init(title: String, isDone: Bool = false, sortOrder: Int = 0, release: ProjectRelease? = nil) {
        self.title = title
        self.isDone = isDone
        self.sortOrder = sortOrder
        self.release = release
    }
}

// MARK: - Quality (issues, risks, tests)

@Model
final class ProjectIssue {
    var title: String
    var detail: String
    var kind: String
    var status: String
    var priority: String
    var createdAt: Date
    /// RICE inputs (1–10); 0 means unset in UI.
    var riceReach: Int = 0
    var riceImpact: Int = 0
    var riceConfidence: Int = 0
    var riceEffort: Int = 0
    /// WSJF inputs; 0 means unset.
    var wsjfCostOfDelay: Double = 0
    var wsjfJobSize: Double = 0
    var project: Project?
    var epic: ProjectEpic?
    var sprint: ProjectSprint?
    var kanbanCard: ProjectKanbanCard?
    var milestone: ProjectMilestone?

    init(
        title: String,
        detail: String = "",
        kind: String = "task",
        status: String = "open",
        priority: String = "medium",
        createdAt: Date = Date(),
        riceReach: Int = 0,
        riceImpact: Int = 0,
        riceConfidence: Int = 0,
        riceEffort: Int = 0,
        wsjfCostOfDelay: Double = 0,
        wsjfJobSize: Double = 0,
        project: Project? = nil,
        epic: ProjectEpic? = nil,
        sprint: ProjectSprint? = nil,
        kanbanCard: ProjectKanbanCard? = nil,
        milestone: ProjectMilestone? = nil
    ) {
        self.title = title
        self.detail = detail
        self.kind = kind
        self.status = status
        self.priority = priority
        self.createdAt = createdAt
        self.riceReach = riceReach
        self.riceImpact = riceImpact
        self.riceConfidence = riceConfidence
        self.riceEffort = riceEffort
        self.wsjfCostOfDelay = wsjfCostOfDelay
        self.wsjfJobSize = wsjfJobSize
        self.project = project
        self.epic = epic
        self.sprint = sprint
        self.kanbanCard = kanbanCard
        self.milestone = milestone
    }
}

@Model
final class ProjectRisk {
    var title: String
    var detail: String
    var likelihood: Int
    var impact: Int
    var mitigation: String
    var status: String
    var project: Project?

    init(
        title: String,
        detail: String = "",
        likelihood: Int = 3,
        impact: Int = 3,
        mitigation: String = "",
        status: String = "open",
        project: Project? = nil
    ) {
        self.title = title
        self.detail = detail
        self.likelihood = likelihood
        self.impact = impact
        self.mitigation = mitigation
        self.status = status
        self.project = project
    }
}

@Model
final class ProjectTestSuite {
    var name: String
    var project: Project?

    @Relationship(deleteRule: .cascade, inverse: \ProjectTestCase.suite)
    var cases: [ProjectTestCase] = []

    init(name: String, project: Project? = nil) {
        self.name = name
        self.project = project
    }
}

@Model
final class ProjectTestCase {
    var title: String
    var steps: String
    var status: String
    var sortOrder: Int
    var suite: ProjectTestSuite?

    init(title: String, steps: String = "", status: String = "planned", sortOrder: Int = 0, suite: ProjectTestSuite? = nil) {
        self.title = title
        self.steps = steps
        self.status = status
        self.sortOrder = sortOrder
        self.suite = suite
    }
}

// MARK: - Launch (changelog)

@Model
final class ProjectChangelogEntry {
    var version: String
    var date: Date
    var body: String
    var project: Project?
    var release: ProjectRelease?

    init(version: String, date: Date = Date(), body: String = "", project: Project? = nil, release: ProjectRelease? = nil) {
        self.version = version
        self.date = date
        self.body = body
        self.project = project
        self.release = release
    }
}

// MARK: - Card scoring (UI helpers)

enum KanbanCardScoring {
    /// RICE: (Reach × Impact × Confidence) / Effort; inputs 1–10, effort must be > 0.
    static func riceScore(card: ProjectKanbanCard) -> Double? {
        guard card.riceEffort > 0,
              card.riceReach > 0, card.riceReach <= 10,
              card.riceImpact > 0, card.riceImpact <= 10,
              card.riceConfidence > 0, card.riceConfidence <= 10 else { return nil }
        return Double(card.riceReach * card.riceImpact * card.riceConfidence) / Double(card.riceEffort)
    }

    /// WSJF: Cost of delay / job size.
    static func wsjfScore(card: ProjectKanbanCard) -> Double? {
        let eps = 0.000_001
        guard card.wsjfJobSize > eps, card.wsjfCostOfDelay > 0 else { return nil }
        return card.wsjfCostOfDelay / max(card.wsjfJobSize, eps)
    }

    static func riceScore(issue: ProjectIssue) -> Double? {
        guard issue.riceEffort > 0,
              issue.riceReach > 0, issue.riceReach <= 10,
              issue.riceImpact > 0, issue.riceImpact <= 10,
              issue.riceConfidence > 0, issue.riceConfidence <= 10 else { return nil }
        return Double(issue.riceReach * issue.riceImpact * issue.riceConfidence) / Double(issue.riceEffort)
    }

    static func wsjfScore(issue: ProjectIssue) -> Double? {
        let eps = 0.000_001
        guard issue.wsjfJobSize > eps, issue.wsjfCostOfDelay > 0 else { return nil }
        return issue.wsjfCostOfDelay / max(issue.wsjfJobSize, eps)
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
