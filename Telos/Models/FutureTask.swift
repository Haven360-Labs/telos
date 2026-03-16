import Foundation
import SwiftData

/// A task planned for the future. Can have subtasks and be moved to today's plan to start working on it.
@Model
final class FutureTask {
    var title: String
    var sortOrder: Int
    var createdAt: Date

    var parent: FutureTask?
    @Relationship(deleteRule: .cascade, inverse: \FutureTask.parent)
    var subtasks: [FutureTask] = []

    init(title: String, sortOrder: Int = 0, createdAt: Date = Date(), parent: FutureTask? = nil) {
        self.title = title
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.parent = parent
    }

    /// True if this is a top-level future task (no parent).
    var isTopLevel: Bool { parent == nil }

    /// Subtasks sorted by sortOrder.
    var sortedSubtasks: [FutureTask] {
        subtasks.sorted { $0.sortOrder < $1.sortOrder }
    }
}
