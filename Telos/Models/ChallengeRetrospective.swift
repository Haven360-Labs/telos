import Foundation
import SwiftData

/// Retrospective for a challenge (one per period; period length is set on the challenge: 3, 7, or 14 days).
@Model
final class ChallengeRetrospective {
    /// 1-based period index (e.g. 1 = first period, 2 = second period, …).
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
