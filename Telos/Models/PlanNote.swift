import Foundation
import SwiftData

enum PlanNoteBlockKind: String, CaseIterable, Identifiable {
    case paragraph
    case heading
    case bullet
    case checklist
    case toggleList

    var id: String { rawValue }

    var title: String {
        switch self {
        case .paragraph: return "Paragraph"
        case .heading: return "Heading"
        case .bullet: return "Bullet list"
        case .checklist: return "Checklist"
        case .toggleList: return "Toggle list"
        }
    }

    var systemImage: String {
        switch self {
        case .paragraph: return "text.alignleft"
        case .heading: return "textformat.size"
        case .bullet: return "list.bullet"
        case .checklist: return "checklist"
        case .toggleList: return "chevron.right"
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

    /// Top-level blocks only (for Notion-style toggle trees), ordered for editing.
    var rootBlocks: [PlanNoteBlock] {
        blocks
            .filter { $0.parentBlock == nil }
            .sorted { lhs, rhs in
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                return lhs.createdAt < rhs.createdAt
            }
    }

    /// Depth-first order, including all nested under toggles. Used for export, normalize, and focus.
    func depthFirstBlocks() -> [PlanNoteBlock] {
        func walk(_ nodes: [PlanNoteBlock]) -> [PlanNoteBlock] {
            var result: [PlanNoteBlock] = []
            for b in nodes {
                result.append(b)
                if !b.sortedChildBlocks.isEmpty { result += walk(b.sortedChildBlocks) }
            }
            return result
        }
        return walk(rootBlocks)
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

    /// Rewrites `sortOrder` to 0…n in depth-first order (matches on-screen block order).
    func normalizeBlockSortOrder() {
        for (i, b) in depthFirstBlocks().enumerated() {
            b.sortOrder = i
        }
    }

    private var plainTextFromBlocks: String {
        func walk(_ b: PlanNoteBlock, depth: Int) -> [String] {
            var out = [b.exportLine(depth: depth)]
            for c in b.sortedChildBlocks { out += walk(c, depth: depth + 1) }
            return out
        }
        return rootBlocks.flatMap { walk($0, depth: 0) }.joined(separator: "\n")
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
    var parentBlock: PlanNoteBlock?

    @Relationship(deleteRule: .cascade, inverse: \PlanNoteBlock.parentBlock)
    var childBlocks: [PlanNoteBlock] = []

    init(
        kind: PlanNoteBlockKind = .paragraph,
        text: String = "",
        sortOrder: Int = 0,
        isChecked: Bool = false,
        createdAt: Date = Date(),
        note: PlanNote? = nil,
        parentBlock: PlanNoteBlock? = nil
    ) {
        self.kindRawValue = kind.rawValue
        self.text = text
        self.sortOrder = sortOrder
        self.isChecked = isChecked
        self.createdAt = createdAt
        self.note = note
        self.parentBlock = parentBlock
    }

    var kind: PlanNoteBlockKind {
        get { PlanNoteBlockKind(rawValue: kindRawValue) ?? .paragraph }
        set { kindRawValue = newValue.rawValue }
    }

    /// - Parameter depth: Nesting under toggles (0 = top level).
    func exportLine(depth: Int) -> String {
        let ind = String(repeating: "  ", count: depth)
        let body: String
        switch kind {
        case .paragraph:
            body = text
        case .heading:
            body = text.isEmpty ? "" : "# \(text)"
        case .bullet:
            body = text.isEmpty ? "- " : "- \(text)"
        case .checklist:
            let marker = isChecked ? "[x]" : "[ ]"
            body = text.isEmpty ? "- \(marker)" : "- \(marker) \(text)"
        case .toggleList:
            // `isChecked` == expanded in the editor. Children always follow in the exported tree.
            let ch = isChecked ? "▾" : "▸"
            body = text.isEmpty ? ch : "\(ch) \(text)"
        }
        return ind + body
    }

    var sortedChildBlocks: [PlanNoteBlock] {
        childBlocks.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
            return lhs.createdAt < rhs.createdAt
        }
    }
}
