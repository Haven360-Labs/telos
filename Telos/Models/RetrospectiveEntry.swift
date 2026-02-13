import Foundation
import SwiftData

/// Optional notes for a retrospective period (day/week/month/quarter). One entry per scope and period start.
@Model
final class RetrospectiveEntry {
    var periodScope: String  // "day", "week", "month", "quarter"
    var periodStart: Date    // start of the period (e.g. start of week)
    var notes: String = ""

    init(periodScope: String, periodStart: Date, notes: String = "") {
        self.periodScope = periodScope
        self.periodStart = periodStart
        self.notes = notes
    }
}
