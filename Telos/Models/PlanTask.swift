import Foundation
import SwiftData
import SwiftUI

/// Eisenhower quadrant: importance (y) × urgency (x). Stored as Int 1–4 on PlanTask.
enum EisenhowerQuadrant: Int, CaseIterable, Identifiable {
    case importantUrgent = 1
    case importantNotUrgent = 2
    case urgentNotImportant = 3
    case notImportantNotUrgent = 4

    var id: Int { rawValue }

    var shortTitle: String {
        switch self {
        case .importantUrgent: return "Do first"
        case .importantNotUrgent: return "Schedule"
        case .urgentNotImportant: return "Delegate / quick"
        case .notImportantNotUrgent: return "Later"
        }
    }

    var fullTitle: String {
        switch self {
        case .importantUrgent: return "Important & Urgent"
        case .importantNotUrgent: return "Important, Not Urgent"
        case .urgentNotImportant: return "Urgent, Not Important"
        case .notImportantNotUrgent: return "Not Important, Not Urgent"
        }
    }

    var systemImage: String {
        switch self {
        case .importantUrgent: return "exclamationmark.circle.fill"
        case .importantNotUrgent: return "calendar"
        case .urgentNotImportant: return "person.2"
        case .notImportantNotUrgent: return "trash"
        }
    }

    var accentColor: Color {
        switch self {
        case .importantUrgent: return .red
        case .importantNotUrgent: return .blue
        case .urgentNotImportant: return .orange
        case .notImportantNotUrgent: return .gray
        }
    }
}

/// A task (or subtask) belonging to a plan day. Top-level tasks have `parent == nil`; subtasks have a non-nil parent.
@Model
final class PlanTask {
    var title: String
    var isCompleted: Bool
    var createdAt: Date
    var sortOrder: Int
    /// Total seconds spent on this task (from countdown/count-up timers).
    var timeSpentSeconds: Double = 0
    /// True if this task was rolled over from a previous day.
    var isRolledOver: Bool = false
    /// True if user marked as no longer needed; excluded from active plan and not rolled forward.
    var isArchived: Bool = false
    /// Eisenhower quadrant (1–4). Only meaningful for top-level tasks; subtasks inherit display from parent.
    var quadrantRaw: Int = EisenhowerQuadrant.notImportantNotUrgent.rawValue

    var planDay: PlanDay?
    var parent: PlanTask?
    @Relationship(deleteRule: .cascade, inverse: \PlanTask.parent)
    var subtasks: [PlanTask] = []

    var quadrant: EisenhowerQuadrant {
        get { EisenhowerQuadrant(rawValue: quadrantRaw) ?? .notImportantNotUrgent }
        set { quadrantRaw = newValue.rawValue }
    }

    init(
        title: String,
        isCompleted: Bool = false,
        createdAt: Date = Date(),
        sortOrder: Int = 0,
        planDay: PlanDay? = nil,
        parent: PlanTask? = nil,
        quadrant: EisenhowerQuadrant = .notImportantNotUrgent
    ) {
        self.title = title
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.planDay = planDay
        self.parent = parent
        self.quadrantRaw = quadrant.rawValue
    }

    /// Top-level tasks only (no parent).
    var isTopLevel: Bool { parent == nil }

    /// Sorted subtasks for display.
    var sortedSubtasks: [PlanTask] {
        subtasks.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Subtasks ordered for display: incomplete first, then completed (at bottom); within each group by sortOrder.
    var subtasksForDisplay: [PlanTask] {
        sortedSubtasks.sorted { t1, t2 in
            if t1.isCompleted != t2.isCompleted { return !t1.isCompleted }
            return t1.sortOrder < t2.sortOrder
        }
    }
}
