import Foundation
import SwiftData

/// A single calendar day — the primary container for the plan.
/// One instance per calendar day; created automatically.
@Model
final class PlanDay {
    /// Calendar day in the user's time zone (time component ignored for identity).
    var date: Date
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \PlanTask.planDay)
    var tasks: [PlanTask] = []

    init(date: Date = Date(), createdAt: Date = Date()) {
        self.date = date
        self.createdAt = createdAt
    }

    /// Top-level tasks only (not archived), sorted by sortOrder then createdAt.
    var sortedTopLevelTasks: [PlanTask] {
        tasks.filter { $0.parent == nil && !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// Top-level tasks that were rolled over from a previous day.
    var rolledOverTopLevelTasks: [PlanTask] {
        sortedTopLevelTasks.filter(\.isRolledOver)
    }

    /// Top-level tasks created today (not rolled over).
    var newTopLevelTasks: [PlanTask] {
        sortedTopLevelTasks.filter { !$0.isRolledOver }
    }

    /// Top-level tasks in the given Eisenhower quadrant, sorted by sortOrder.
    func topLevelTasks(in quadrant: EisenhowerQuadrant) -> [PlanTask] {
        sortedTopLevelTasks.filter { $0.quadrant == quadrant }
    }

    /// Calendar day (year, month, day) for equality.
    static func isSameCalendarDay(_ a: Date, _ b: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(a, inSameDayAs: b)
    }
}
