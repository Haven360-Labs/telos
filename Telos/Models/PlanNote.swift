import Foundation
import SwiftData

/// A note — can be tied to a plan day or standalone.
@Model
final class PlanNote {
    var content: String
    var createdAt: Date
    var planDay: PlanDay?

    init(content: String, createdAt: Date = Date(), planDay: PlanDay? = nil) {
        self.content = content
        self.createdAt = createdAt
        self.planDay = planDay
    }

    /// First line or truncated content for list preview.
    var preview: String {
        let firstLine = content.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? content
        if firstLine.count > 80 {
            return String(firstLine.prefix(77)) + "..."
        }
        return firstLine
    }
}
