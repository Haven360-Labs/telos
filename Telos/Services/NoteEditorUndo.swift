import Foundation
import SwiftData
import Observation

struct NoteBlockSnapshot: Equatable {
    var kind: PlanNoteBlockKind
    var text: String
    var sortOrder: Int
    var isChecked: Bool
    var parentIndex: Int?
}

struct NoteEditorSnapshot: Equatable {
    var title: String
    var blocks: [NoteBlockSnapshot]
    var focusBlockIndex: Int?

    static func capture(from note: PlanNote, focusBlockID: PersistentIdentifier?) -> NoteEditorSnapshot {
        let ordered = note.depthFirstBlocks()
        let focusIndex = focusBlockID.flatMap { id in
            ordered.firstIndex { $0.persistentModelID == id }
        }
        var indexByID: [PersistentIdentifier: Int] = [:]
        for (index, block) in ordered.enumerated() {
            indexByID[block.persistentModelID] = index
        }
        let blocks = ordered.map { block in
            NoteBlockSnapshot(
                kind: block.kind,
                text: block.text,
                sortOrder: block.sortOrder,
                isChecked: block.isChecked,
                parentIndex: block.parentBlock.flatMap { indexByID[$0.persistentModelID] }
            )
        }
        return NoteEditorSnapshot(title: note.title, blocks: blocks, focusBlockIndex: focusIndex)
    }

    @discardableResult
    func apply(to note: PlanNote, modelContext: ModelContext) -> PersistentIdentifier? {
        note.title = title

        for block in Array(note.blocks) {
            modelContext.delete(block)
        }
        note.blocks.removeAll()

        var created: [PlanNoteBlock] = []
        for snapshot in blocks {
            let block = PlanNoteBlock(
                kind: snapshot.kind,
                text: snapshot.text,
                sortOrder: snapshot.sortOrder,
                isChecked: snapshot.isChecked,
                note: note
            )
            modelContext.insert(block)
            note.blocks.append(block)
            created.append(block)
        }

        for (index, snapshot) in blocks.enumerated() where index < created.count {
            if let parentIndex = snapshot.parentIndex, parentIndex < created.count {
                created[index].parentBlock = created[parentIndex]
            }
        }

        note.normalizeBlockSortOrder()
        note.rebuildContentCache()

        if let focusBlockIndex, focusBlockIndex < created.count {
            return created[focusBlockIndex].persistentModelID
        }
        return created.first?.persistentModelID
    }
}

@MainActor
@Observable
final class NoteUndoController {
    let undoManager = UndoManager()
    private(set) var canUndo = false
    private(set) var canRedo = false

    private weak var note: PlanNote?
    private weak var modelContext: ModelContext?
    var onFocusChange: ((PersistentIdentifier?) -> Void)?
    private var undoObserver: NSObjectProtocol?
    private var redoObserver: NSObjectProtocol?
    private var checkpointObserver: NSObjectProtocol?

    init() {
        let center = NotificationCenter.default
        undoObserver = center.addObserver(
            forName: .NSUndoManagerDidUndoChange,
            object: undoManager,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshUndoState() }
        }
        redoObserver = center.addObserver(
            forName: .NSUndoManagerDidRedoChange,
            object: undoManager,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshUndoState() }
        }
        checkpointObserver = center.addObserver(
            forName: .NSUndoManagerCheckpoint,
            object: undoManager,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshUndoState() }
        }
        refreshUndoState()
    }

    func configure(note: PlanNote, modelContext: ModelContext) {
        self.note = note
        self.modelContext = modelContext
    }

    func reset() {
        undoManager.removeAllActions()
        refreshUndoState()
    }

    func registerChange(actionName: String, before: NoteEditorSnapshot, after: NoteEditorSnapshot) {
        guard before != after else { return }
        undoManager.registerUndo(withTarget: self) { controller in
            controller.applySnapshot(before, actionName: actionName, reverseSnapshot: after)
        }
        undoManager.setActionName(actionName)
        refreshUndoState()
    }

    private func applySnapshot(
        _ snapshot: NoteEditorSnapshot,
        actionName: String,
        reverseSnapshot: NoteEditorSnapshot
    ) {
        guard let note, let modelContext else { return }
        let focusID = snapshot.apply(to: note, modelContext: modelContext)
        try? modelContext.save()
        onFocusChange?(focusID)
        undoManager.registerUndo(withTarget: self) { controller in
            controller.applySnapshot(reverseSnapshot, actionName: actionName, reverseSnapshot: snapshot)
        }
        undoManager.setActionName(actionName)
        refreshUndoState()
    }

    private func refreshUndoState() {
        canUndo = undoManager.canUndo
        canRedo = undoManager.canRedo
    }
}

@MainActor
@Observable
final class NoteEditingSession {
    var activeUndoManager: UndoManager?
    var noteKeyboardFocused = false
    var canUndo = false
    var canRedo = false

    var handlesUndoRedo: Bool {
        activeUndoManager != nil && noteKeyboardFocused
    }

    func activate(_ controller: NoteUndoController) {
        activeUndoManager = controller.undoManager
        canUndo = controller.canUndo
        canRedo = controller.canRedo
    }

    func sync(from controller: NoteUndoController) {
        canUndo = controller.canUndo
        canRedo = controller.canRedo
    }

    func deactivate() {
        activeUndoManager = nil
        noteKeyboardFocused = false
        canUndo = false
        canRedo = false
    }

    func undo() {
        activeUndoManager?.undo()
    }

    func redo() {
        activeUndoManager?.redo()
    }
}
