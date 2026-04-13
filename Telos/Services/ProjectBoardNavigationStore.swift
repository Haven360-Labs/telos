import Foundation
import SwiftData
import SwiftUI

/// Coordinates jumping from Today (linked `PlanTask`) to **Project → Board & tasks** for the same kanban card.
@Observable
final class ProjectBoardNavigationStore {
    /// When set, `ContentView` switches to the Project sidebar; `ProjectHubView` selects the project and **Board & tasks**; the board section picks the right scope and clears this value.
    var pendingKanbanCardID: PersistentIdentifier?

    func openBoard(for card: ProjectKanbanCard) {
        pendingKanbanCardID = card.persistentModelID
    }

    func clearPendingKanbanCardFocus() {
        pendingKanbanCardID = nil
    }
}
