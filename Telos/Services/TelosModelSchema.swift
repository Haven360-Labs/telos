import SwiftData

/// Single source of truth for the persisted model graph (backup, app container, previews).
enum TelosModelSchema {
    static var schema: Schema {
        Schema([
            PlanDay.self,
            PlanTask.self,
            PlanNote.self,
            PlanNoteBlock.self,
            Project.self,
            ProjectKanbanColumn.self,
            ProjectKanbanCard.self,
            ProjectKanbanChecklistItem.self,
            ProjectSprint.self,
            ProjectRetrospective.self,
            ProjectDocument.self,
            ProjectTheme.self,
            ProjectEpic.self,
            ProjectRoadmapItem.self,
            ProjectDecision.self,
            ProjectMilestone.self,
            ProjectRelease.self,
            ReleaseChecklistItem.self,
            ProjectIssue.self,
            ProjectRisk.self,
            ProjectTestSuite.self,
            ProjectTestCase.self,
            ProjectChangelogEntry.self,
            RetrospectiveEntry.self,
            Challenge.self,
            ChallengeDayProgress.self,
            ChallengeRetrospective.self,
            FutureTask.self,
            PlanGoal.self,
        ])
    }
}
