import Foundation
import SwiftData

// MARK: - Errors

enum TelosBackupError: LocalizedError {
    case unsupportedFormat(Int)
    case missingReference(entity: String, uuid: UUID)
    case corruptData(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let v):
            return "This backup format (version \(v)) is not supported."
        case .missingReference(let entity, let uuid):
            return "Backup is invalid: \(entity) references missing id \(uuid.uuidString)."
        case .corruptData(let msg):
            return msg
        }
    }
}

// MARK: - Envelope

fileprivate struct TelosBackupEnvelope: Codable {
    var formatVersion: Int
    var exportedAt: Date
    var planDays: [PlanDayDTO]
    var planTasks: [PlanTaskDTO]
    var planNotes: [PlanNoteDTO]
    var planNoteBlocks: [PlanNoteBlockDTO]
    var projects: [ProjectDTO]
    var projectKanbanColumns: [ProjectKanbanColumnDTO]
    var projectKanbanCards: [ProjectKanbanCardDTO]
    var projectKanbanChecklistItems: [ProjectKanbanChecklistItemDTO]
    var projectSprints: [ProjectSprintDTO]
    var projectRetrospectives: [ProjectRetrospectiveDTO]
    var projectDocuments: [ProjectDocumentDTO]
    var projectThemes: [ProjectThemeDTO]
    var projectEpics: [ProjectEpicDTO]
    var projectRoadmapItems: [ProjectRoadmapItemDTO]
    var projectDecisions: [ProjectDecisionDTO]
    var projectMilestones: [ProjectMilestoneDTO]
    var projectReleases: [ProjectReleaseDTO]
    var releaseChecklistItems: [ReleaseChecklistItemDTO]
    var projectIssues: [ProjectIssueDTO]
    var projectRisks: [ProjectRiskDTO]
    var projectTestSuites: [ProjectTestSuiteDTO]
    var projectTestCases: [ProjectTestCaseDTO]
    var projectChangelogEntries: [ProjectChangelogEntryDTO]
    var retrospectiveEntries: [RetrospectiveEntryDTO]
    var challenges: [ChallengeDTO]
    var challengeDayProgress: [ChallengeDayProgressDTO]
    var challengeRetrospectives: [ChallengeRetrospectiveDTO]
    var futureTasks: [FutureTaskDTO]
    var planGoals: [PlanGoalDTO]
}

// MARK: - DTOs

fileprivate struct PlanDayDTO: Codable {
    var id: UUID
    var date: Date
    var createdAt: Date
}

fileprivate struct PlanTaskDTO: Codable {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var createdAt: Date
    var sortOrder: Int
    var timeSpentSeconds: Double
    var isRolledOver: Bool
    var isArchived: Bool
    var quadrantRaw: Int
    var scheduledDate: Date?
    var planDayId: UUID?
    var parentId: UUID?
    var linkedChallengeId: UUID?
    var linkedKanbanCardId: UUID?
}

fileprivate struct PlanNoteDTO: Codable {
    var id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var planDayId: UUID?
    var projectId: UUID?
}

fileprivate struct PlanNoteBlockDTO: Codable {
    var id: UUID
    var kindRawValue: String
    var text: String
    var sortOrder: Int
    var isChecked: Bool
    var createdAt: Date
    var noteId: UUID?
    /// When set, this block is nested under another block (e.g. Notion-style toggles). Omitted in older exports.
    var parentBlockId: UUID? = nil
}

fileprivate struct ProjectDTO: Codable {
    var id: UUID
    var name: String
    var createdAt: Date
    var isArchived: Bool
    var archivedAt: Date?
}

fileprivate struct ProjectKanbanColumnDTO: Codable {
    var id: UUID
    var title: String
    var sortOrder: Int
    var projectId: UUID?
    var sprintId: UUID?
}

fileprivate struct ProjectKanbanCardDTO: Codable {
    var id: UUID
    var title: String
    var body: String
    var sortOrder: Int
    var columnId: UUID?
    var epicId: UUID?
    var milestoneId: UUID?
}

fileprivate struct ProjectKanbanChecklistItemDTO: Codable {
    var id: UUID
    var title: String
    var isDone: Bool
    var sortOrder: Int
    var cardId: UUID?
}

fileprivate struct ProjectSprintDTO: Codable {
    var id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    var notes: String
    var isArchived: Bool
    var archivedAt: Date?
    var projectId: UUID?
}

fileprivate struct ProjectRetrospectiveDTO: Codable {
    var id: UUID
    var notes: String
    var createdAt: Date
    var projectId: UUID?
    var sprintId: UUID?
}

fileprivate struct ProjectDocumentDTO: Codable {
    var id: UUID
    var displayName: String
    var bookmarkData: Data
    var addedAt: Date
    var projectId: UUID?
}

fileprivate struct ProjectThemeDTO: Codable {
    var id: UUID
    var title: String
    var sortOrder: Int
    var projectId: UUID?
}

fileprivate struct ProjectEpicDTO: Codable {
    var id: UUID
    var title: String
    var sortOrder: Int
    var projectId: UUID?
    var themeId: UUID?
}

fileprivate struct ProjectRoadmapItemDTO: Codable {
    var id: UUID
    var title: String
    var targetStart: Date
    var targetEnd: Date?
    var notes: String
    var sortOrder: Int
    var projectId: UUID?
    var epicId: UUID?
}

fileprivate struct ProjectDecisionDTO: Codable {
    var id: UUID
    var title: String
    var decidedAt: Date
    var context: String
    var decision: String
    var rationale: String
    var projectId: UUID?
}

fileprivate struct ProjectMilestoneDTO: Codable {
    var id: UUID
    var title: String
    var targetDate: Date
    var isCompleted: Bool
    var sortOrder: Int
    var projectId: UUID?
    var epicId: UUID?
    var roadmapItemId: UUID?
}

fileprivate struct ProjectReleaseDTO: Codable {
    var id: UUID
    var version: String
    var targetDate: Date?
    var status: String
    var projectId: UUID?
}

fileprivate struct ReleaseChecklistItemDTO: Codable {
    var id: UUID
    var title: String
    var isDone: Bool
    var sortOrder: Int
    var releaseId: UUID?
}

fileprivate struct ProjectIssueDTO: Codable {
    var id: UUID
    var title: String
    var detail: String
    var kind: String
    var status: String
    var priority: String
    var createdAt: Date
    var projectId: UUID?
    var epicId: UUID?
    var sprintId: UUID?
    var kanbanCardId: UUID?
    var milestoneId: UUID?
}

fileprivate struct ProjectRiskDTO: Codable {
    var id: UUID
    var title: String
    var detail: String
    var likelihood: Int
    var impact: Int
    var mitigation: String
    var status: String
    var projectId: UUID?
}

fileprivate struct ProjectTestSuiteDTO: Codable {
    var id: UUID
    var name: String
    var projectId: UUID?
}

fileprivate struct ProjectTestCaseDTO: Codable {
    var id: UUID
    var title: String
    var steps: String
    var status: String
    var sortOrder: Int
    var suiteId: UUID?
}

fileprivate struct ProjectChangelogEntryDTO: Codable {
    var id: UUID
    var version: String
    var date: Date
    var body: String
    var projectId: UUID?
    var releaseId: UUID?
}

fileprivate struct RetrospectiveEntryDTO: Codable {
    var id: UUID
    var periodScope: String
    var periodStart: Date
    var notes: String
}

fileprivate struct ChallengeDTO: Codable {
    var id: UUID
    var title: String
    var challengeDescription: String?
    var totalDays: Int
    var startDate: Date
    var createdAt: Date
    var allowMarkPastDays: Bool?
    var excludeWeekends: Bool?
    var retrospectivePeriodDays: Int?
}

fileprivate struct ChallengeDayProgressDTO: Codable {
    var id: UUID
    var dayIndex: Int
    var notes: String
    var isCompleted: Bool
    var updatedAt: Date
    var timeSpentSeconds: Double
    var challengeId: UUID?
}

fileprivate struct ChallengeRetrospectiveDTO: Codable {
    var id: UUID
    var periodIndex: Int
    var notes: String
    var updatedAt: Date
    var challengeId: UUID?
}

fileprivate struct FutureTaskDTO: Codable {
    var id: UUID
    var title: String
    var sortOrder: Int
    var createdAt: Date
    var parentId: UUID?
}

fileprivate struct PlanGoalDTO: Codable {
    var id: UUID
    var title: String
    var sortOrder: Int
    var createdAt: Date
    var month: Date
    var weekNumber: Int
    var isCompleted: Bool
}

// MARK: - Full backup

enum TelosFullBackup {
    static let currentFormatVersion = 1

    /// Encodes the entire SwiftData graph as JSON.
    static func exportSnapshotJSON(modelContext: ModelContext) throws -> Data {
        var idMap: [PersistentIdentifier: UUID] = [:]

        func uuid(for model: some PersistentModel) -> UUID {
            if let u = idMap[model.persistentModelID] { return u }
            let u = UUID()
            idMap[model.persistentModelID] = u
            return u
        }

        let planDays: [PlanDayDTO] = try modelContext.fetch(FetchDescriptor<PlanDay>()).map {
            PlanDayDTO(id: uuid(for: $0), date: $0.date, createdAt: $0.createdAt)
        }
        let planTasks: [PlanTaskDTO] = try modelContext.fetch(FetchDescriptor<PlanTask>()).map {
            PlanTaskDTO(
                id: uuid(for: $0),
                title: $0.title,
                isCompleted: $0.isCompleted,
                createdAt: $0.createdAt,
                sortOrder: $0.sortOrder,
                timeSpentSeconds: $0.timeSpentSeconds,
                isRolledOver: $0.isRolledOver,
                isArchived: $0.isArchived,
                quadrantRaw: $0.quadrantRaw,
                scheduledDate: $0.scheduledDate,
                planDayId: $0.planDay.map { uuid(for: $0) },
                parentId: $0.parent.map { uuid(for: $0) },
                linkedChallengeId: $0.linkedChallenge.map { uuid(for: $0) },
                linkedKanbanCardId: $0.linkedKanbanCard.map { uuid(for: $0) }
            )
        }
        let planNotes: [PlanNoteDTO] = try modelContext.fetch(FetchDescriptor<PlanNote>()).map {
            PlanNoteDTO(
                id: uuid(for: $0),
                title: $0.title,
                content: $0.content,
                createdAt: $0.createdAt,
                planDayId: $0.planDay.map { uuid(for: $0) },
                projectId: $0.project.map { uuid(for: $0) }
            )
        }
        let planNoteBlocks: [PlanNoteBlockDTO] = try modelContext.fetch(FetchDescriptor<PlanNoteBlock>()).map {
            PlanNoteBlockDTO(
                id: uuid(for: $0),
                kindRawValue: $0.kindRawValue,
                text: $0.text,
                sortOrder: $0.sortOrder,
                isChecked: $0.isChecked,
                createdAt: $0.createdAt,
                noteId: $0.note.map { uuid(for: $0) },
                parentBlockId: $0.parentBlock.map { uuid(for: $0) }
            )
        }
        let projects: [ProjectDTO] = try modelContext.fetch(FetchDescriptor<Project>()).map {
            ProjectDTO(id: uuid(for: $0), name: $0.name, createdAt: $0.createdAt, isArchived: $0.isArchived, archivedAt: $0.archivedAt)
        }
        let projectKanbanColumns: [ProjectKanbanColumnDTO] = try modelContext.fetch(FetchDescriptor<ProjectKanbanColumn>()).map {
            ProjectKanbanColumnDTO(
                id: uuid(for: $0),
                title: $0.title,
                sortOrder: $0.sortOrder,
                projectId: $0.project.map { uuid(for: $0) },
                sprintId: $0.sprint.map { uuid(for: $0) }
            )
        }
        let projectKanbanCards: [ProjectKanbanCardDTO] = try modelContext.fetch(FetchDescriptor<ProjectKanbanCard>()).map {
            ProjectKanbanCardDTO(
                id: uuid(for: $0),
                title: $0.title,
                body: $0.body,
                sortOrder: $0.sortOrder,
                columnId: $0.column.map { uuid(for: $0) },
                epicId: $0.epic.map { uuid(for: $0) },
                milestoneId: $0.milestone.map { uuid(for: $0) }
            )
        }
        let projectKanbanChecklistItems: [ProjectKanbanChecklistItemDTO] = try modelContext.fetch(FetchDescriptor<ProjectKanbanChecklistItem>()).map {
            ProjectKanbanChecklistItemDTO(id: uuid(for: $0), title: $0.title, isDone: $0.isDone, sortOrder: $0.sortOrder, cardId: $0.card.map { uuid(for: $0) })
        }
        let projectSprints: [ProjectSprintDTO] = try modelContext.fetch(FetchDescriptor<ProjectSprint>()).map {
            ProjectSprintDTO(
                id: uuid(for: $0),
                title: $0.title,
                startDate: $0.startDate,
                endDate: $0.endDate,
                notes: $0.notes,
                isArchived: $0.isArchived,
                archivedAt: $0.archivedAt,
                projectId: $0.project.map { uuid(for: $0) }
            )
        }
        let projectRetrospectives: [ProjectRetrospectiveDTO] = try modelContext.fetch(FetchDescriptor<ProjectRetrospective>()).map {
            ProjectRetrospectiveDTO(
                id: uuid(for: $0),
                notes: $0.notes,
                createdAt: $0.createdAt,
                projectId: $0.project.map { uuid(for: $0) },
                sprintId: $0.sprint.map { uuid(for: $0) }
            )
        }
        let projectDocuments: [ProjectDocumentDTO] = try modelContext.fetch(FetchDescriptor<ProjectDocument>()).map {
            ProjectDocumentDTO(id: uuid(for: $0), displayName: $0.displayName, bookmarkData: $0.bookmarkData, addedAt: $0.addedAt, projectId: $0.project.map { uuid(for: $0) })
        }
        let projectThemes: [ProjectThemeDTO] = try modelContext.fetch(FetchDescriptor<ProjectTheme>()).map {
            ProjectThemeDTO(id: uuid(for: $0), title: $0.title, sortOrder: $0.sortOrder, projectId: $0.project.map { uuid(for: $0) })
        }
        let projectEpics: [ProjectEpicDTO] = try modelContext.fetch(FetchDescriptor<ProjectEpic>()).map {
            ProjectEpicDTO(id: uuid(for: $0), title: $0.title, sortOrder: $0.sortOrder, projectId: $0.project.map { uuid(for: $0) }, themeId: $0.theme.map { uuid(for: $0) })
        }
        let projectRoadmapItems: [ProjectRoadmapItemDTO] = try modelContext.fetch(FetchDescriptor<ProjectRoadmapItem>()).map {
            ProjectRoadmapItemDTO(
                id: uuid(for: $0),
                title: $0.title,
                targetStart: $0.targetStart,
                targetEnd: $0.targetEnd,
                notes: $0.notes,
                sortOrder: $0.sortOrder,
                projectId: $0.project.map { uuid(for: $0) },
                epicId: $0.epic.map { uuid(for: $0) }
            )
        }
        let projectDecisions: [ProjectDecisionDTO] = try modelContext.fetch(FetchDescriptor<ProjectDecision>()).map {
            ProjectDecisionDTO(
                id: uuid(for: $0),
                title: $0.title,
                decidedAt: $0.decidedAt,
                context: $0.context,
                decision: $0.decision,
                rationale: $0.rationale,
                projectId: $0.project.map { uuid(for: $0) }
            )
        }
        let projectMilestones: [ProjectMilestoneDTO] = try modelContext.fetch(FetchDescriptor<ProjectMilestone>()).map {
            ProjectMilestoneDTO(
                id: uuid(for: $0),
                title: $0.title,
                targetDate: $0.targetDate,
                isCompleted: $0.isCompleted,
                sortOrder: $0.sortOrder,
                projectId: $0.project.map { uuid(for: $0) },
                epicId: $0.epic.map { uuid(for: $0) },
                roadmapItemId: $0.roadmapItem.map { uuid(for: $0) }
            )
        }
        let projectReleases: [ProjectReleaseDTO] = try modelContext.fetch(FetchDescriptor<ProjectRelease>()).map {
            ProjectReleaseDTO(id: uuid(for: $0), version: $0.version, targetDate: $0.targetDate, status: $0.status, projectId: $0.project.map { uuid(for: $0) })
        }
        let releaseChecklistItems: [ReleaseChecklistItemDTO] = try modelContext.fetch(FetchDescriptor<ReleaseChecklistItem>()).map {
            ReleaseChecklistItemDTO(id: uuid(for: $0), title: $0.title, isDone: $0.isDone, sortOrder: $0.sortOrder, releaseId: $0.release.map { uuid(for: $0) })
        }
        let projectIssues: [ProjectIssueDTO] = try modelContext.fetch(FetchDescriptor<ProjectIssue>()).map {
            ProjectIssueDTO(
                id: uuid(for: $0),
                title: $0.title,
                detail: $0.detail,
                kind: $0.kind,
                status: $0.status,
                priority: $0.priority,
                createdAt: $0.createdAt,
                projectId: $0.project.map { uuid(for: $0) },
                epicId: $0.epic.map { uuid(for: $0) },
                sprintId: $0.sprint.map { uuid(for: $0) },
                kanbanCardId: $0.kanbanCard.map { uuid(for: $0) },
                milestoneId: $0.milestone.map { uuid(for: $0) }
            )
        }
        let projectRisks: [ProjectRiskDTO] = try modelContext.fetch(FetchDescriptor<ProjectRisk>()).map {
            ProjectRiskDTO(
                id: uuid(for: $0),
                title: $0.title,
                detail: $0.detail,
                likelihood: $0.likelihood,
                impact: $0.impact,
                mitigation: $0.mitigation,
                status: $0.status,
                projectId: $0.project.map { uuid(for: $0) }
            )
        }
        let projectTestSuites: [ProjectTestSuiteDTO] = try modelContext.fetch(FetchDescriptor<ProjectTestSuite>()).map {
            ProjectTestSuiteDTO(id: uuid(for: $0), name: $0.name, projectId: $0.project.map { uuid(for: $0) })
        }
        let projectTestCases: [ProjectTestCaseDTO] = try modelContext.fetch(FetchDescriptor<ProjectTestCase>()).map {
            ProjectTestCaseDTO(id: uuid(for: $0), title: $0.title, steps: $0.steps, status: $0.status, sortOrder: $0.sortOrder, suiteId: $0.suite.map { uuid(for: $0) })
        }
        let projectChangelogEntries: [ProjectChangelogEntryDTO] = try modelContext.fetch(FetchDescriptor<ProjectChangelogEntry>()).map {
            ProjectChangelogEntryDTO(id: uuid(for: $0), version: $0.version, date: $0.date, body: $0.body, projectId: $0.project.map { uuid(for: $0) }, releaseId: $0.release.map { uuid(for: $0) })
        }
        let retrospectiveEntries: [RetrospectiveEntryDTO] = try modelContext.fetch(FetchDescriptor<RetrospectiveEntry>()).map {
            RetrospectiveEntryDTO(id: uuid(for: $0), periodScope: $0.periodScope, periodStart: $0.periodStart, notes: $0.notes)
        }
        let challenges: [ChallengeDTO] = try modelContext.fetch(FetchDescriptor<Challenge>()).map {
            ChallengeDTO(
                id: uuid(for: $0),
                title: $0.title,
                challengeDescription: $0.challengeDescription,
                totalDays: $0.totalDays,
                startDate: $0.startDate,
                createdAt: $0.createdAt,
                allowMarkPastDays: $0.allowMarkPastDays,
                excludeWeekends: $0.excludeWeekends,
                retrospectivePeriodDays: $0.retrospectivePeriodDays
            )
        }
        let challengeDayProgress: [ChallengeDayProgressDTO] = try modelContext.fetch(FetchDescriptor<ChallengeDayProgress>()).map {
            ChallengeDayProgressDTO(
                id: uuid(for: $0),
                dayIndex: $0.dayIndex,
                notes: $0.notes,
                isCompleted: $0.isCompleted,
                updatedAt: $0.updatedAt,
                timeSpentSeconds: $0.timeSpentSeconds,
                challengeId: $0.challenge.map { uuid(for: $0) }
            )
        }
        let challengeRetrospectives: [ChallengeRetrospectiveDTO] = try modelContext.fetch(FetchDescriptor<ChallengeRetrospective>()).map {
            ChallengeRetrospectiveDTO(id: uuid(for: $0), periodIndex: $0.periodIndex, notes: $0.notes, updatedAt: $0.updatedAt, challengeId: $0.challenge.map { uuid(for: $0) })
        }
        let futureTasks: [FutureTaskDTO] = try modelContext.fetch(FetchDescriptor<FutureTask>()).map {
            FutureTaskDTO(id: uuid(for: $0), title: $0.title, sortOrder: $0.sortOrder, createdAt: $0.createdAt, parentId: $0.parent.map { uuid(for: $0) })
        }
        let planGoals: [PlanGoalDTO] = try modelContext.fetch(FetchDescriptor<PlanGoal>()).map {
            PlanGoalDTO(
                id: uuid(for: $0),
                title: $0.title,
                sortOrder: $0.sortOrder,
                createdAt: $0.createdAt,
                month: $0.month,
                weekNumber: $0.weekNumber,
                isCompleted: $0.isCompleted
            )
        }

        let envelope = TelosBackupEnvelope(
            formatVersion: currentFormatVersion,
            exportedAt: Date(),
            planDays: planDays,
            planTasks: planTasks,
            planNotes: planNotes,
            planNoteBlocks: planNoteBlocks,
            projects: projects,
            projectKanbanColumns: projectKanbanColumns,
            projectKanbanCards: projectKanbanCards,
            projectKanbanChecklistItems: projectKanbanChecklistItems,
            projectSprints: projectSprints,
            projectRetrospectives: projectRetrospectives,
            projectDocuments: projectDocuments,
            projectThemes: projectThemes,
            projectEpics: projectEpics,
            projectRoadmapItems: projectRoadmapItems,
            projectDecisions: projectDecisions,
            projectMilestones: projectMilestones,
            projectReleases: projectReleases,
            releaseChecklistItems: releaseChecklistItems,
            projectIssues: projectIssues,
            projectRisks: projectRisks,
            projectTestSuites: projectTestSuites,
            projectTestCases: projectTestCases,
            projectChangelogEntries: projectChangelogEntries,
            retrospectiveEntries: retrospectiveEntries,
            challenges: challenges,
            challengeDayProgress: challengeDayProgress,
            challengeRetrospectives: challengeRetrospectives,
            futureTasks: futureTasks,
            planGoals: planGoals
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(envelope)
    }

    /// Replaces all data in the store with the backup (destructive).
    static func importSnapshot(data: Data, modelContext: ModelContext) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(TelosBackupEnvelope.self, from: data)
        guard envelope.formatVersion == currentFormatVersion else {
            throw TelosBackupError.unsupportedFormat(envelope.formatVersion)
        }

        try deleteAllExisting(modelContext: modelContext)
        try insertEnvelope(envelope, modelContext: modelContext)
        try modelContext.save()
    }

    // MARK: - Delete all

    private static func deleteAllExisting(modelContext: ModelContext) throws {
        func del<T: PersistentModel>(_ type: T.Type) throws {
            let items = try modelContext.fetch(FetchDescriptor<T>())
            for item in items {
                modelContext.delete(item)
            }
        }

        try del(PlanNoteBlock.self)
        try del(PlanNote.self)

        let tasks = try modelContext.fetch(FetchDescriptor<PlanTask>())
        let sortedTasks = tasks.sorted { planTaskDepth($0) > planTaskDepth($1) }
        for t in sortedTasks { modelContext.delete(t) }

        try del(PlanDay.self)
        try del(ChallengeDayProgress.self)
        try del(ChallengeRetrospective.self)
        try del(Challenge.self)

        let futureTasks = try modelContext.fetch(FetchDescriptor<FutureTask>())
        let sortedFuture = futureTasks.sorted { futureTaskDepth($0) > futureTaskDepth($1) }
        for t in sortedFuture { modelContext.delete(t) }

        try del(PlanGoal.self)
        try del(RetrospectiveEntry.self)
        try del(ReleaseChecklistItem.self)
        try del(ProjectChangelogEntry.self)
        try del(ProjectIssue.self)
        try del(ProjectKanbanChecklistItem.self)
        try del(ProjectTestCase.self)
        try del(ProjectTestSuite.self)
        try del(ProjectRisk.self)
        try del(ProjectKanbanCard.self)
        try del(ProjectKanbanColumn.self)
        try del(ProjectMilestone.self)
        try del(ProjectRelease.self)
        try del(ProjectRoadmapItem.self)
        try del(ProjectDecision.self)
        try del(ProjectEpic.self)
        try del(ProjectTheme.self)
        try del(ProjectDocument.self)
        try del(ProjectRetrospective.self)
        try del(ProjectSprint.self)
        try del(Project.self)
    }

    private static func planTaskDepth(_ t: PlanTask) -> Int {
        var d = 0
        var p: PlanTask? = t.parent
        while let cur = p {
            d += 1
            p = cur.parent
        }
        return d
    }

    private static func futureTaskDepth(_ t: FutureTask) -> Int {
        var d = 0
        var p: FutureTask? = t.parent
        while let cur = p {
            d += 1
            p = cur.parent
        }
        return d
    }

    // MARK: - Insert

    private static func insertEnvelope(_ e: TelosBackupEnvelope, modelContext: ModelContext) throws {
        func req<T>(_ map: [UUID: T], _ id: UUID?, entity: String) throws -> T? {
            guard let id else { return nil }
            guard let v = map[id] else { throw TelosBackupError.missingReference(entity: entity, uuid: id) }
            return v
        }

        var planDays: [UUID: PlanDay] = [:]
        for d in e.planDays {
            let o = PlanDay(date: d.date, createdAt: d.createdAt)
            modelContext.insert(o)
            planDays[d.id] = o
        }

        var projects: [UUID: Project] = [:]
        for p in e.projects {
            let o = Project(name: p.name, createdAt: p.createdAt, isArchived: p.isArchived, archivedAt: p.archivedAt)
            modelContext.insert(o)
            projects[p.id] = o
        }

        var challenges: [UUID: Challenge] = [:]
        for c in e.challenges {
            let o = Challenge(
                title: c.title,
                challengeDescription: c.challengeDescription,
                totalDays: c.totalDays,
                startDate: c.startDate,
                createdAt: c.createdAt,
                allowMarkPastDays: c.allowMarkPastDays ?? true,
                excludeWeekends: c.excludeWeekends ?? false,
                retrospectivePeriodDays: c.retrospectivePeriodDays ?? 14
            )
            modelContext.insert(o)
            challenges[c.id] = o
        }

        for r in e.retrospectiveEntries {
            let o = RetrospectiveEntry(periodScope: r.periodScope, periodStart: r.periodStart, notes: r.notes)
            modelContext.insert(o)
        }

        for g in e.planGoals {
            let o = PlanGoal(title: g.title, sortOrder: g.sortOrder, createdAt: g.createdAt, month: g.month, weekNumber: g.weekNumber, isCompleted: g.isCompleted)
            modelContext.insert(o)
        }

        var sprints: [UUID: ProjectSprint] = [:]
        for s in e.projectSprints {
            let proj = try req(projects, s.projectId, entity: "ProjectSprint.project")
            let o = ProjectSprint(title: s.title, startDate: s.startDate, endDate: s.endDate, notes: s.notes, project: proj, isArchived: s.isArchived, archivedAt: s.archivedAt)
            modelContext.insert(o)
            sprints[s.id] = o
        }

        var themes: [UUID: ProjectTheme] = [:]
        for t in e.projectThemes {
            let proj = try req(projects, t.projectId, entity: "ProjectTheme.project")
            let o = ProjectTheme(title: t.title, sortOrder: t.sortOrder, project: proj)
            modelContext.insert(o)
            themes[t.id] = o
        }

        var epics: [UUID: ProjectEpic] = [:]
        for ep in e.projectEpics {
            let proj = try req(projects, ep.projectId, entity: "ProjectEpic.project")
            let theme = try req(themes, ep.themeId, entity: "ProjectEpic.theme")
            let o = ProjectEpic(title: ep.title, sortOrder: ep.sortOrder, project: proj, theme: theme)
            modelContext.insert(o)
            epics[ep.id] = o
        }

        var roadmapItems: [UUID: ProjectRoadmapItem] = [:]
        for ri in e.projectRoadmapItems {
            let proj = try req(projects, ri.projectId, entity: "ProjectRoadmapItem.project")
            let epic = try req(epics, ri.epicId, entity: "ProjectRoadmapItem.epic")
            let o = ProjectRoadmapItem(title: ri.title, targetStart: ri.targetStart, targetEnd: ri.targetEnd, notes: ri.notes, sortOrder: ri.sortOrder, project: proj, epic: epic)
            modelContext.insert(o)
            roadmapItems[ri.id] = o
        }

        var milestones: [UUID: ProjectMilestone] = [:]
        for m in e.projectMilestones {
            let proj = try req(projects, m.projectId, entity: "ProjectMilestone.project")
            let epic = try req(epics, m.epicId, entity: "ProjectMilestone.epic")
            let rmi = try req(roadmapItems, m.roadmapItemId, entity: "ProjectMilestone.roadmapItem")
            let o = ProjectMilestone(title: m.title, targetDate: m.targetDate, isCompleted: m.isCompleted, sortOrder: m.sortOrder, project: proj, epic: epic, roadmapItem: rmi)
            modelContext.insert(o)
            milestones[m.id] = o
        }

        var releases: [UUID: ProjectRelease] = [:]
        for r in e.projectReleases {
            let proj = try req(projects, r.projectId, entity: "ProjectRelease.project")
            let o = ProjectRelease(version: r.version, targetDate: r.targetDate, status: r.status, project: proj)
            modelContext.insert(o)
            releases[r.id] = o
        }

        for pr in e.projectRetrospectives {
            let proj = try req(projects, pr.projectId, entity: "ProjectRetrospective.project")
            let sp = try req(sprints, pr.sprintId, entity: "ProjectRetrospective.sprint")
            let o = ProjectRetrospective(notes: pr.notes, createdAt: pr.createdAt, project: proj, sprint: sp)
            modelContext.insert(o)
        }

        for d in e.projectDocuments {
            let proj = try req(projects, d.projectId, entity: "ProjectDocument.project")
            let o = ProjectDocument(displayName: d.displayName, bookmarkData: d.bookmarkData, addedAt: d.addedAt, project: proj)
            modelContext.insert(o)
        }

        for dec in e.projectDecisions {
            let proj = try req(projects, dec.projectId, entity: "ProjectDecision.project")
            let o = ProjectDecision(title: dec.title, decidedAt: dec.decidedAt, context: dec.context, decision: dec.decision, rationale: dec.rationale, project: proj)
            modelContext.insert(o)
        }

        var columns: [UUID: ProjectKanbanColumn] = [:]
        for col in e.projectKanbanColumns {
            let proj = try req(projects, col.projectId, entity: "ProjectKanbanColumn.project")
            let sp = try req(sprints, col.sprintId, entity: "ProjectKanbanColumn.sprint")
            let o = ProjectKanbanColumn(title: col.title, sortOrder: col.sortOrder, project: proj, sprint: sp)
            modelContext.insert(o)
            columns[col.id] = o
        }

        var cards: [UUID: ProjectKanbanCard] = [:]
        for card in e.projectKanbanCards {
            let col = try req(columns, card.columnId, entity: "ProjectKanbanCard.column")
            let epic = try req(epics, card.epicId, entity: "ProjectKanbanCard.epic")
            let ms = try req(milestones, card.milestoneId, entity: "ProjectKanbanCard.milestone")
            let o = ProjectKanbanCard(title: card.title, body: card.body, sortOrder: card.sortOrder, column: col, epic: epic, milestone: ms)
            modelContext.insert(o)
            cards[card.id] = o
        }

        for item in e.projectKanbanChecklistItems {
            let card = try req(cards, item.cardId, entity: "ProjectKanbanChecklistItem.card")
            let o = ProjectKanbanChecklistItem(title: item.title, isDone: item.isDone, sortOrder: item.sortOrder, card: card)
            modelContext.insert(o)
        }

        for issue in e.projectIssues {
            let proj = try req(projects, issue.projectId, entity: "ProjectIssue.project")
            let epic = try req(epics, issue.epicId, entity: "ProjectIssue.epic")
            let sp = try req(sprints, issue.sprintId, entity: "ProjectIssue.sprint")
            let kc = try req(cards, issue.kanbanCardId, entity: "ProjectIssue.kanbanCard")
            let ms = try req(milestones, issue.milestoneId, entity: "ProjectIssue.milestone")
            let o = ProjectIssue(
                title: issue.title,
                detail: issue.detail,
                kind: issue.kind,
                status: issue.status,
                priority: issue.priority,
                createdAt: issue.createdAt,
                project: proj,
                epic: epic,
                sprint: sp,
                kanbanCard: kc,
                milestone: ms
            )
            modelContext.insert(o)
        }

        for item in e.releaseChecklistItems {
            let rel = try req(releases, item.releaseId, entity: "ReleaseChecklistItem.release")
            let o = ReleaseChecklistItem(title: item.title, isDone: item.isDone, sortOrder: item.sortOrder, release: rel)
            modelContext.insert(o)
        }

        for ce in e.projectChangelogEntries {
            let proj = try req(projects, ce.projectId, entity: "ProjectChangelogEntry.project")
            let rel = try req(releases, ce.releaseId, entity: "ProjectChangelogEntry.release")
            let o = ProjectChangelogEntry(version: ce.version, date: ce.date, body: ce.body, project: proj, release: rel)
            modelContext.insert(o)
        }

        var suites: [UUID: ProjectTestSuite] = [:]
        for s in e.projectTestSuites {
            let proj = try req(projects, s.projectId, entity: "ProjectTestSuite.project")
            let o = ProjectTestSuite(name: s.name, project: proj)
            modelContext.insert(o)
            suites[s.id] = o
        }

        for tc in e.projectTestCases {
            let su = try req(suites, tc.suiteId, entity: "ProjectTestCase.suite")
            let o = ProjectTestCase(title: tc.title, steps: tc.steps, status: tc.status, sortOrder: tc.sortOrder, suite: su)
            modelContext.insert(o)
        }

        for r in e.projectRisks {
            let proj = try req(projects, r.projectId, entity: "ProjectRisk.project")
            let o = ProjectRisk(title: r.title, detail: r.detail, likelihood: r.likelihood, impact: r.impact, mitigation: r.mitigation, status: r.status, project: proj)
            modelContext.insert(o)
        }

        for cp in e.challengeDayProgress {
            let ch = try req(challenges, cp.challengeId, entity: "ChallengeDayProgress.challenge")
            let o = ChallengeDayProgress(dayIndex: cp.dayIndex, notes: cp.notes, isCompleted: cp.isCompleted, updatedAt: cp.updatedAt, timeSpentSeconds: cp.timeSpentSeconds, challenge: ch)
            modelContext.insert(o)
        }

        for cr in e.challengeRetrospectives {
            let ch = try req(challenges, cr.challengeId, entity: "ChallengeRetrospective.challenge")
            let o = ChallengeRetrospective(periodIndex: cr.periodIndex, notes: cr.notes, updatedAt: cr.updatedAt, challenge: ch)
            modelContext.insert(o)
        }

        var futureMap: [UUID: FutureTask] = [:]
        var futureDTOs = e.futureTasks
        while !futureDTOs.isEmpty {
            let before = futureDTOs.count
            var next: [FutureTaskDTO] = []
            for ft in futureDTOs {
                if let pid = ft.parentId {
                    guard futureMap[pid] != nil else {
                        next.append(ft)
                        continue
                    }
                }
                let parent = ft.parentId.flatMap { futureMap[$0] }
                let o = FutureTask(title: ft.title, sortOrder: ft.sortOrder, createdAt: ft.createdAt, parent: parent)
                modelContext.insert(o)
                futureMap[ft.id] = o
            }
            futureDTOs = next
            if futureDTOs.count == before {
                throw TelosBackupError.corruptData("FutureTask parent chain could not be resolved.")
            }
        }

        var notesById: [UUID: PlanNote] = [:]
        for n in e.planNotes {
            let day = try req(planDays, n.planDayId, entity: "PlanNote.planDay")
            let proj = try req(projects, n.projectId, entity: "PlanNote.project")
            let o = PlanNote(title: n.title, content: n.content, createdAt: n.createdAt, planDay: day, project: proj)
            modelContext.insert(o)
            notesById[n.id] = o
        }

        var planNoteBlockById: [UUID: PlanNoteBlock] = [:]
        for nb in e.planNoteBlocks {
            let note = try req(notesById, nb.noteId, entity: "PlanNoteBlock.note")
            let o = PlanNoteBlock(
                kind: PlanNoteBlockKind(rawValue: nb.kindRawValue) ?? .paragraph,
                text: nb.text,
                sortOrder: nb.sortOrder,
                isChecked: nb.isChecked,
                createdAt: nb.createdAt,
                note: note,
                parentBlock: nil
            )
            modelContext.insert(o)
            planNoteBlockById[nb.id] = o
        }
        for nb in e.planNoteBlocks {
            if let pid = nb.parentBlockId, let p = planNoteBlockById[pid] {
                planNoteBlockById[nb.id]?.parentBlock = p
            }
        }

        var taskMap: [UUID: PlanTask] = [:]
        var taskDTOs = e.planTasks
        while !taskDTOs.isEmpty {
            let before = taskDTOs.count
            var next: [PlanTaskDTO] = []
            for td in taskDTOs {
                if let pid = td.parentId {
                    guard taskMap[pid] != nil else {
                        next.append(td)
                        continue
                    }
                }
                let day = try req(planDays, td.planDayId, entity: "PlanTask.planDay")
                let parent = td.parentId.flatMap { taskMap[$0] }
                let ch = try req(challenges, td.linkedChallengeId, entity: "PlanTask.linkedChallenge")
                let kc = try req(cards, td.linkedKanbanCardId, entity: "PlanTask.linkedKanbanCard")
                let o = PlanTask(
                    title: td.title,
                    isCompleted: td.isCompleted,
                    createdAt: td.createdAt,
                    sortOrder: td.sortOrder,
                    planDay: day,
                    parent: parent,
                    quadrant: EisenhowerQuadrant(rawValue: td.quadrantRaw) ?? .notImportantNotUrgent,
                    scheduledDate: td.scheduledDate,
                    linkedKanbanCard: kc
                )
                o.timeSpentSeconds = td.timeSpentSeconds
                o.isRolledOver = td.isRolledOver
                o.isArchived = td.isArchived
                o.quadrantRaw = td.quadrantRaw
                o.linkedChallenge = ch
                modelContext.insert(o)
                taskMap[td.id] = o
            }
            taskDTOs = next
            if taskDTOs.count == before {
                throw TelosBackupError.corruptData("PlanTask parent chain could not be resolved.")
            }
        }
    }
}
