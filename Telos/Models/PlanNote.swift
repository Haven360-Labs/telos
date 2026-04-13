import Foundation
import SwiftData

/// A note — can be tied to a plan day or standalone.
@Model
final class PlanNote {
    var title: String = ""
    var content: String
    var createdAt: Date
    var planDay: PlanDay?
    var project: Project?

    init(title: String = "", content: String, createdAt: Date = Date(), planDay: PlanDay? = nil, project: Project? = nil) {
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.planDay = planDay
        self.project = project
    }

    /// Title for list display; falls back to content preview when title is empty.
    var displayTitle: String {
        if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return title }
        return preview
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
