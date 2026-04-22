import Foundation
import SwiftData

enum PlanNoteBlockKind: String, CaseIterable, Identifiable {
    case paragraph
    case heading
    case bullet
    case checklist

    var id: String { rawValue }

    var title: String {
        switch self {
        case .paragraph: return "Paragraph"
        case .heading: return "Heading"
        case .bullet: return "Bullet list"
        case .checklist: return "Checklist"
        }
    }

    var systemImage: String {
        switch self {
        case .paragraph: return "text.alignleft"
        case .heading: return "textformat.size"
        case .bullet: return "list.bullet"
        case .checklist: return "checklist"
        }
    }
}

/// A note — can be tied to a plan day or standalone.
@Model
final class PlanNote {
    var title: String = ""
    var content: String
    var createdAt: Date
    var planDay: PlanDay?
    var project: Project?

    @Relationship(deleteRule: .cascade, inverse: \PlanNoteBlock.note)
    var blocks: [PlanNoteBlock] = []

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
        let fallback = preview.trimmingCharacters(in: .whitespacesAndNewlines)
        return fallback.isEmpty ? "Untitled note" : fallback
    }

    /// First line or truncated content for list preview.
    var preview: String {
        let source = blocks.isEmpty ? content : plainTextFromBlocks
        let firstLine = source
            .split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init) ?? source
        if firstLine.count > 80 {
            return String(firstLine.prefix(77)) + "..."
        }
        return firstLine
    }

    var sortedBlocks: [PlanNoteBlock] {
        blocks.sorted { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.sortOrder < rhs.sortOrder
        }
    }

    var exportContent: String {
        blocks.isEmpty ? content : plainTextFromBlocks
    }

    func ensureBlocks(modelContext: ModelContext) {
        guard blocks.isEmpty else {
            rebuildContentCache()
            return
        }

        let lines = content.isEmpty ? [""] : content.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            let block = PlanNoteBlock(kind: .paragraph, text: line, sortOrder: index, note: self)
            modelContext.insert(block)
            blocks.append(block)
        }
        rebuildContentCache()
    }

    func rebuildContentCache() {
        guard !blocks.isEmpty else { return }
        content = plainTextFromBlocks
    }

    private var plainTextFromBlocks: String {
        sortedBlocks.map(\.exportLine).joined(separator: "\n")
    }
}

@Model
final class PlanNoteBlock {
    var kindRawValue: String
    var text: String
    var sortOrder: Int
    var isChecked: Bool
    var createdAt: Date
    var note: PlanNote?

    init(
        kind: PlanNoteBlockKind = .paragraph,
        text: String = "",
        sortOrder: Int = 0,
        isChecked: Bool = false,
        createdAt: Date = Date(),
        note: PlanNote? = nil
    ) {
        self.kindRawValue = kind.rawValue
        self.text = text
        self.sortOrder = sortOrder
        self.isChecked = isChecked
        self.createdAt = createdAt
        self.note = note
    }

    var kind: PlanNoteBlockKind {
        get { PlanNoteBlockKind(rawValue: kindRawValue) ?? .paragraph }
        set { kindRawValue = newValue.rawValue }
    }

    var exportLine: String {
        switch kind {
        case .paragraph:
            return text
        case .heading:
            return text.isEmpty ? "" : "# \(text)"
        case .bullet:
            return text.isEmpty ? "- " : "- \(text)"
        case .checklist:
            let marker = isChecked ? "[x]" : "[ ]"
            return text.isEmpty ? "- \(marker)" : "- \(marker) \(text)"
        }
    }
}
