import Foundation
import SwiftData

/// A goal entry for a month or a specific week. Month is the start of the calendar month; weekNumber 0 = overall month goals, 1–4 = Week 1–4.
@Model
final class PlanGoal {
    var title: String
    var sortOrder: Int
    var createdAt: Date
    /// Start of the calendar month (e.g. first day of March).
    var month: Date
    /// 0 = overall month goal; 1–4 = Week 1–4 within the month.
    var weekNumber: Int
    var isCompleted: Bool = false

    init(title: String, sortOrder: Int = 0, createdAt: Date = Date(), month: Date, weekNumber: Int, isCompleted: Bool = false) {
        self.title = title
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.month = month
        self.weekNumber = weekNumber
        self.isCompleted = isCompleted
    }
}
