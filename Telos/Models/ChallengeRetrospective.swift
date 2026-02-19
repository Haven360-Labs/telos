import Foundation
import SwiftData

/// Biweekly retrospective for a challenge (one per 14-day period).
@Model
final class ChallengeRetrospective {
    /// 1-based period index (1 = days 1–14, 2 = 15–28, …).
    var periodIndex: Int
    var notes: String
    var updatedAt: Date

    var challenge: Challenge?

    init(periodIndex: Int, notes: String = "", updatedAt: Date = Date(), challenge: Challenge? = nil) {
        self.periodIndex = periodIndex
        self.notes = notes
        self.updatedAt = updatedAt
        self.challenge = challenge
    }
}
