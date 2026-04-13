import SwiftData
import SwiftUI

/// Identifies a kanban card for in-app drag-and-drop (same process / same store).
struct KanbanCardDragPayload: Transferable, Codable, Equatable {
    /// Stable within the current ModelContainer; used to resolve the card after drop.
    var persistentModelID: PersistentIdentifier

    init(card: ProjectKanbanCard) {
        self.persistentModelID = card.persistentModelID
    }

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .json)
    }
}

enum KanbanBoardDragSupport {
    /// Resolve a card from a drag payload (same model context as the board).
    static func card(for payload: KanbanCardDragPayload, modelContext: ModelContext) -> ProjectKanbanCard? {
        (try? modelContext.model(for: payload.persistentModelID)) as? ProjectKanbanCard
    }

    /// Reassign contiguous sortOrder values for cards in a column (preserves relative order).
    static func renumber(column: ProjectKanbanColumn) {
        let sorted = column.cards.sorted { $0.sortOrder < $1.sortOrder }
        for (index, card) in sorted.enumerated() {
            card.sortOrder = index
            card.column = column
        }
    }

    /// Move `dragged` into `targetColumn`, inserting before `targetCard` if non-nil (same column = reorder).
    static func drop(
        dragged: ProjectKanbanCard,
        targetColumn: ProjectKanbanColumn,
        before targetCard: ProjectKanbanCard?,
        modelContext: ModelContext
    ) {
        if let target = targetCard, target.persistentModelID == dragged.persistentModelID { return }

        let oldColumn = dragged.column

        dragged.column = targetColumn

        var ordered = targetColumn.cards
            .filter { $0.persistentModelID != dragged.persistentModelID }
            .sorted { $0.sortOrder < $1.sortOrder }

        let insertIndex: Int
        if let target = targetCard,
           let idx = ordered.firstIndex(where: { $0.persistentModelID == target.persistentModelID }) {
            insertIndex = idx
        } else {
            insertIndex = ordered.count
        }

        ordered.insert(dragged, at: insertIndex)
        for (index, card) in ordered.enumerated() {
            card.sortOrder = index
            card.column = targetColumn
        }

        if let old = oldColumn, old.persistentModelID != targetColumn.persistentModelID {
            renumber(column: old)
        }

        try? modelContext.save()
    }
}
