import Foundation
import SwiftData

/// Progress recorded for a single day of a challenge (1-based day index).
@Model
final class ChallengeDayProgress {
    /// 1-based day index (1...totalDays).
    var dayIndex: Int
    /// Optional notes or description of what was done.
    var notes: String
    /// Whether the user marked this day as done.
    var isCompleted: Bool
    var updatedAt: Date

    var challenge: Challenge?

    init(dayIndex: Int, notes: String = "", isCompleted: Bool = false, updatedAt: Date = Date(), challenge: Challenge? = nil) {
        self.dayIndex = dayIndex
        self.notes = notes
        self.isCompleted = isCompleted
        self.updatedAt = updatedAt
        self.challenge = challenge
    }
}
