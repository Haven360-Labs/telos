import SwiftUI
import SwiftData
import AppKit

struct NotesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StreakStore.self) private var streakStore
    @Query(
        filter: #Predicate<PlanNote> { $0.project == nil },
        sort: \PlanNote.createdAt,
        order: .reverse
    ) private var notes: [PlanNote]
    @State private var selectedNote: PlanNote?

    var body: some View {
        Group {
            if let note = selectedNote {
                NotePageEditorView(
                    note: note,
                    modelContext: modelContext,
                    onDismiss: { selectedNote = nil },
                    onNewNote: { addNote() }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ZStack(alignment: .bottomTrailing) {
                    List(selection: $selectedNote) {
                        ForEach(notes) { note in
                            Button {
                                selectedNote = note
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(note.displayTitle)
                                        .lineLimit(2)
                                        .foregroundStyle(.primary)
                                    Text(note.createdAt, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    selectedNote = note
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    deleteNote(note)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .onDelete(perform: deleteNotesAtOffsets)
                    }
                    .listStyle(.inset)

                    NoteNewNoteFloatingButton(action: { addNote() })
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(selectedNote == nil ? "Notes" : "Note")
        .toolbar {
            if selectedNote != nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        try? modelContext.save()
                        selectedNote = nil
                    }
                    .keyboardShortcut(.cancelAction)
                    .keyboardShortcut(.defaultAction)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Delete", role: .destructive) {
                        if let note = selectedNote {
                            deleteNote(note)
                            selectedNote = nil
                        }
                    }
                }
            } else {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        addNote()
                    } label: {
                        Label("Add note", systemImage: "square.and.pencil")
                    }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                }
            }
        }
    }

    private func addNote() {
        let note = PlanNote(title: "", content: "")
        modelContext.insert(note)
        note.ensureBlocks(modelContext: modelContext)
        try? modelContext.save()
        streakStore.recordUsage()
        selectedNote = note
    }

    private func deleteNote(_ note: PlanNote) {
        if selectedNote?.id == note.id {
            selectedNote = nil
        }
        modelContext.delete(note)
        try? modelContext.save()
        streakStore.recordUsage()
    }

    private func deleteNotesAtOffsets(_ offsets: IndexSet) {
        for index in offsets {
            let note = notes[index]
            if selectedNote?.id == note.id {
                selectedNote = nil
            }
            modelContext.delete(note)
        }
        try? modelContext.save()
        streakStore.recordUsage()
    }
}

private struct NoteNewNoteFloatingButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 22, height: 22)
                .frame(width: 50, height: 50)
                .background {
                    Circle()
                        .fill(.tint)
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.22), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .help("Add note")
        .padding(24)
    }
}

struct NotePageEditorView: View {
    @Bindable var note: PlanNote
    var modelContext: ModelContext
    var onDismiss: () -> Void
    /// When set, shows a floating control to create another note (parent switches selection).
    var onNewNote: (() -> Void)? = nil

    @State private var focusedBlockID: PersistentIdentifier?
    @State private var slashMenuBlockID: PersistentIdentifier?
    @FocusState private var isTitleFieldFocused: Bool

    private var shouldStartEditingInTitle: Bool {
        note.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    TextField("Untitled", text: $note.title, prompt: Text("Untitled"))
                        .font(.system(size: 30, weight: .bold))
                        .textFieldStyle(.plain)
                        .focused($isTitleFieldFocused)
                        .onSubmit {
                            saveNoteChange()
                            moveFocusToFirstBlockIfPossible()
                        }
                        .onChange(of: note.title) { _, _ in saveNoteChange() }

                    Text(note.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // VStack (not LazyVStack): when a block’s height changes, a lazy stack can leave
                    // the following block at the old position, so the two draw on top of each other.
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(note.rootBlocks) { block in
                            NoteBlockSubtree(
                                block: block,
                                depth: 0,
                                focusedBlockID: focusedBlockID,
                                slashMenuBlockID: slashMenuBlockID,
                                onFocus: { id in
                                    focusedBlockID = id
                                    isTitleFieldFocused = false
                                },
                                onSlashMenuChange: { slashMenuBlockID = $0 },
                                onTextChanged: saveNoteChange,
                                onSplit: splitBlock,
                                onBackspaceEmpty: deleteEmptyBlock,
                                onSlashForBlock: { b in slashMenuBlockID = b.persistentModelID },
                                onConvert: convert,
                                onDelete: deleteBlock
                            )
                            .id(block.persistentModelID)
                        }

                        Button {
                            appendBlockAtEnd()
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .help("Add block")
                        .padding(.leading, 30)
                        .padding(.top, 4)
                    }
                }
                .padding(32)
                .frame(maxWidth: 820, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .top)
            }
            .background(.regularMaterial.opacity(0.2))
            .onChange(of: focusedBlockID) { _, newValue in
                guard let newValue else { return }
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }

            if let onNewNote {
                NoteNewNoteFloatingButton(action: onNewNote)
            }
            }
        }
        .onAppear {
            prepareBlocks()
            if shouldStartEditingInTitle {
                DispatchQueue.main.async { isTitleFieldFocused = true }
            }
        }
        .onChange(of: isTitleFieldFocused) { _, focused in
            if focused { focusedBlockID = nil }
        }
        .onChange(of: focusedBlockID) { _, newID in
            if newID != nil { isTitleFieldFocused = false }
        }
        .onDisappear {
            note.rebuildContentCache()
            try? modelContext.save()
        }
    }

    private func moveFocusToFirstBlockIfPossible() {
        guard let first = note.rootBlocks.first else { return }
        isTitleFieldFocused = false
        focusedBlockID = first.persistentModelID
    }

    private func prepareBlocks() {
        note.ensureBlocks(modelContext: modelContext)
        try? modelContext.save()
        if focusedBlockID == nil, !shouldStartEditingInTitle {
            focusedBlockID = note.rootBlocks.first?.persistentModelID
        }
    }

    private func saveNoteChange() {
        note.rebuildContentCache()
        try? modelContext.save()
    }

    private func splitBlock(_ block: PlanNoteBlock, at cursor: Int) {
        let text = block.text
        let offset = max(0, min(cursor, text.count))
        let splitIndex = text.index(text.startIndex, offsetBy: offset)
        let before = String(text[..<splitIndex])
        let after = String(text[splitIndex...])
        let newKind: PlanNoteBlockKind
        if block.kind == .heading { newKind = .paragraph } else if block.kind == .toggleList { newKind = .paragraph } else { newKind = block.kind }

        block.text = before
        if block.kind == .toggleList { block.isChecked = true }

        let newBlock = PlanNoteBlock(kind: newKind, text: after, sortOrder: 0, note: note)
        if block.kind == .toggleList { newBlock.parentBlock = block } else { newBlock.parentBlock = block.parentBlock }
        modelContext.insert(newBlock)
        note.blocks.append(newBlock)
        note.normalizeBlockSortOrder()
        note.rebuildContentCache()
        try? modelContext.save()
        focusedBlockID = newBlock.persistentModelID
    }

    private func appendBlockAtEnd() {
        let newBlock = PlanNoteBlock(
            kind: .paragraph,
            text: "",
            sortOrder: (note.rootBlocks.map(\.sortOrder).max() ?? -1) + 1,
            note: note,
            parentBlock: nil
        )
        modelContext.insert(newBlock)
        note.blocks.append(newBlock)
        note.normalizeBlockSortOrder()
        saveNoteChange()
        focusedBlockID = newBlock.persistentModelID
    }

    private func deleteEmptyBlock(_ block: PlanNoteBlock) {
        guard block.text.isEmpty else { return }
        deleteBlock(block)
    }

    private func deleteBlock(_ block: PlanNoteBlock) {
        let tree = note.depthFirstBlocks()
        guard tree.count > 1 else {
            block.kind = .paragraph
            block.text = ""
            block.isChecked = false
            block.parentBlock = nil
            slashMenuBlockID = nil
            focusedBlockID = block.persistentModelID
            saveNoteChange()
            return
        }

        let index = tree.firstIndex { $0.persistentModelID == block.persistentModelID } ?? 0
        let focusTarget = index > 0 ? tree[index - 1] : tree[min(index + 1, tree.count - 1)]
        note.blocks.removeAll { $0.persistentModelID == block.persistentModelID }
        modelContext.delete(block)
        note.normalizeBlockSortOrder()
        slashMenuBlockID = nil
        note.rebuildContentCache()
        try? modelContext.save()
        focusedBlockID = focusTarget.persistentModelID
    }

    private func convert(_ block: PlanNoteBlock, to kind: PlanNoteBlockKind) {
        if block.kind == .toggleList, kind != .toggleList {
            for child in Array(block.sortedChildBlocks) {
                child.parentBlock = block.parentBlock
            }
        }
        block.kind = kind
        switch kind {
        case .checklist: block.isChecked = false
        case .toggleList: block.isChecked = true
        default: block.isChecked = false
        }
        slashMenuBlockID = nil
        note.normalizeBlockSortOrder()
        focusedBlockID = block.persistentModelID
        saveNoteChange()
    }
}

private struct NoteBlockSubtree: View {
    @Bindable var block: PlanNoteBlock
    var depth: CGFloat
    var focusedBlockID: PersistentIdentifier?
    var slashMenuBlockID: PersistentIdentifier?
    var onFocus: (PersistentIdentifier) -> Void
    var onSlashMenuChange: (PersistentIdentifier?) -> Void
    var onTextChanged: () -> Void
    var onSplit: (PlanNoteBlock, Int) -> Void
    var onBackspaceEmpty: (PlanNoteBlock) -> Void
    var onSlashForBlock: (PlanNoteBlock) -> Void
    var onConvert: (PlanNoteBlock, PlanNoteBlockKind) -> Void
    var onDelete: (PlanNoteBlock) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            NoteBlockRow(
                block: block,
                isFocused: focusedBlockID == block.persistentModelID,
                isShowingBlockMenu: Binding(
                    get: { slashMenuBlockID == block.persistentModelID },
                    set: { isShowing in
                        if !isShowing { onSlashMenuChange(nil) }
                    }
                ),
                onTextChanged: onTextChanged,
                onReturn: { onSplit(block, $0) },
                onBackspaceEmpty: { onBackspaceEmpty(block) },
                onSlash: { onSlashForBlock(block) },
                onConvert: { onConvert(block, $0) },
                onDelete: { onDelete(block) },
                onBecameFirstResponder: { onFocus(block.persistentModelID) }
            )
            .padding(.leading, depth * 20)

            if block.kind == .toggleList, block.isChecked {
                ForEach(block.sortedChildBlocks) { child in
                    NoteBlockSubtree(
                        block: child,
                        depth: depth + 1,
                        focusedBlockID: focusedBlockID,
                        slashMenuBlockID: slashMenuBlockID,
                        onFocus: onFocus,
                        onSlashMenuChange: onSlashMenuChange,
                        onTextChanged: onTextChanged,
                        onSplit: onSplit,
                        onBackspaceEmpty: onBackspaceEmpty,
                        onSlashForBlock: onSlashForBlock,
                        onConvert: onConvert,
                        onDelete: onDelete
                    )
                    .id(child.persistentModelID)
                }
            }
        }
    }
}

private struct NoteBlockRow: View {
    @Bindable var block: PlanNoteBlock
    var isFocused: Bool
    @Binding var isShowingBlockMenu: Bool
    var onTextChanged: () -> Void
    var onReturn: (Int) -> Void
    var onBackspaceEmpty: () -> Void
    var onSlash: () -> Void
    var onConvert: (PlanNoteBlockKind) -> Void
    var onDelete: () -> Void
    var onBecameFirstResponder: () -> Void = {}

    @State private var height: CGFloat = 28
    @State private var isHovering = false
    @State private var hoverEndWorkItem: DispatchWorkItem?

    private var minHeight: CGFloat {
        block.kind == .heading ? 40 : 28
    }

    private var placeholder: String {
        switch block.kind {
        case .heading: return "Heading"
        default: return "Write"
        }
    }

    private var showsBlockControls: Bool {
        isHovering || isFocused || isShowingBlockMenu
    }

    private var prefixColumnWidth: CGFloat { 24 }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Menu {
                blockTypeButtons
                Divider()
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete block", systemImage: "trash")
                }
            } label: {
                Image(systemName: "square.grid.2x2")
                    .frame(width: 22, height: 22)
            }
            .menuStyle(.borderlessButton)
            .buttonStyle(.plain)
            .opacity(showsBlockControls ? 1 : 0)
            .allowsHitTesting(showsBlockControls)
            .animation(.easeOut(duration: 0.12), value: showsBlockControls)
            .help("Block type")

            prefix
                .frame(width: prefixColumnWidth, height: minHeight, alignment: .top)

            ZStack(alignment: .topLeading) {
                if block.text.isEmpty {
                    Text(placeholder)
                        .font(block.kind == .heading ? .title2.bold() : .body)
                        .foregroundStyle(.tertiary)
                        .padding(.top, block.kind == .heading ? 5 : 4)
                        .allowsHitTesting(false)
                }

                BlockTextView(
                    text: $block.text,
                    kind: block.kind,
                    isFocused: isFocused,
                    onTextChanged: onTextChanged,
                    onReturn: onReturn,
                    onBackspaceEmpty: onBackspaceEmpty,
                    onSlash: onSlash,
                    onHeightChange: { height = $0 },
                    onBecomeFirstResponder: onBecameFirstResponder
                )
                // Fixed height (not min+max) so the representable can’t size to a one-line intrinsic height while text wraps; that caused overlap with the next block.
                .frame(height: max(height, minHeight))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .popover(isPresented: $isShowingBlockMenu, arrowEdge: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    blockTypeButtons
                }
                .padding(10)
                .frame(width: 190)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onHover(perform: updateHoverState)
        .onDisappear {
            hoverEndWorkItem?.cancel()
        }
    }

    private func updateHoverState(_ hovering: Bool) {
        hoverEndWorkItem?.cancel()

        if hovering {
            isHovering = true
        } else {
            let workItem = DispatchWorkItem {
                isHovering = false
            }
            hoverEndWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: workItem)
        }
    }

    @ViewBuilder
    private var prefix: some View {
        switch block.kind {
        case .paragraph, .heading:
            Color.clear
        case .bullet:
            Text("•")
                .font(.title2)
                .foregroundStyle(.secondary)
                .padding(.top, 1)
        case .checklist:
            Toggle("", isOn: $block.isChecked)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .padding(.top, 1)
                .onChange(of: block.isChecked) { _, _ in onTextChanged() }
        case .toggleList:
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { block.isChecked.toggle() }
                onTextChanged()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isFocused ? .primary : .secondary)
                    .rotationEffect(.degrees(block.isChecked ? 90 : 0))
                    .frame(width: 20, height: 22, alignment: .center)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(block.isChecked ? "Collapse" : "Expand")
        }
    }

    @ViewBuilder
    private var blockTypeButtons: some View {
        ForEach(PlanNoteBlockKind.allCases) { kind in
            Button {
                onConvert(kind)
            } label: {
                Label(kind.title, systemImage: kind.systemImage)
            }
        }
    }
}

private struct BlockTextView: NSViewRepresentable {
    @Binding var text: String
    var kind: PlanNoteBlockKind
    var isFocused: Bool
    var onTextChanged: () -> Void
    var onReturn: (Int) -> Void
    var onBackspaceEmpty: () -> Void
    var onSlash: () -> Void
    var onHeightChange: (CGFloat) -> Void
    var onBecomeFirstResponder: (() -> Void)? = nil

    var minimumHeight: CGFloat {
        kind == .heading ? 40 : 28
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> BlockNSTextView {
        let textView = BlockNSTextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 0, height: 2)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        // When true, the text system can outgrow the SwiftUI frame, causing clashing layout and line overlap.
        textView.isVerticallyResizable = false
        textView.maxSize = NSSize(width: 100_000, height: 100_000)
        textView.font = nsFont
        textView.string = text
        applyDynamicColors(to: textView)
        textView.commandHandler = context.coordinator.handle
        return textView
    }

    func updateNSView(_ textView: BlockNSTextView, context: Context) {
        context.coordinator.parent = self
        textView.onBecameFirstResponder = { onBecomeFirstResponder?() }
        let coordinator = context.coordinator
        textView.onWidthForLayoutChange = { [weak textView] in
            guard let textView else { return }
            DispatchQueue.main.async {
                coordinator.recalculateHeight(textView)
            }
        }
        textView.commandHandler = context.coordinator.handle
        textView.font = nsFont
        applyDynamicColors(to: textView)

        if textView.string != text {
            let selection = textView.selectedRange()
            textView.string = text
            applyDynamicColors(to: textView)
            textView.setSelectedRange(NSRange(location: min(selection.location, text.count), length: 0))
        }

        DispatchQueue.main.async {
            context.coordinator.recalculateHeight(textView)
            if isFocused, textView.window?.firstResponder !== textView {
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    private func applyDynamicColors(to textView: NSTextView) {
        textView.textColor = .labelColor
        textView.insertionPointColor = .controlAccentColor
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor.selectedTextBackgroundColor,
            .foregroundColor: NSColor.selectedTextColor,
        ]
        textView.typingAttributes = [
            .font: nsFont,
            .foregroundColor: NSColor.labelColor,
        ]

        let fullRange = NSRange(location: 0, length: textView.string.utf16.count)
        if fullRange.length > 0 {
            textView.textStorage?.addAttributes([
                .font: nsFont,
                .foregroundColor: NSColor.labelColor,
            ], range: fullRange)
        }
    }

    private var nsFont: NSFont {
        switch kind {
        case .heading:
            return .systemFont(ofSize: 22, weight: .semibold)
        default:
            return .systemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: BlockTextView

        init(_ parent: BlockTextView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? BlockNSTextView else { return }
            if parent.text != textView.string {
                parent.text = textView.string
            }
            parent.onTextChanged()
            recalculateHeight(textView)
        }

        func handle(_ command: BlockTextCommand, textView: BlockNSTextView) -> Bool {
            switch command {
            case .returnKey:
                parent.onReturn(textView.selectedRange().location)
                return true
            case .backspaceAtStart:
                parent.onBackspaceEmpty()
                return true
            case .slash:
                parent.onSlash()
                return true
            }
        }

        func recalculateHeight(_ textView: NSTextView) {
            let width = textView.bounds.width
            if width < 2 {
                DispatchQueue.main.async { [weak self, weak textView] in
                    guard let self, let textView, textView.bounds.width > 1 else { return }
                    self.recalculateHeight(textView)
                }
                return
            }
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else {
                parent.onHeightChange(parent.minimumHeight)
                return
            }
            let charLen = (textView.string as NSString).length
            if charLen == 0 {
                parent.onHeightChange(parent.minimumHeight)
                return
            }
            layoutManager.invalidateLayout(forCharacterRange: NSRange(location: 0, length: charLen), actualCharacterRange: nil)
            layoutManager.ensureLayout(for: textContainer)
            let glyphCount = layoutManager.numberOfGlyphs
            if glyphCount == 0 {
                parent.onHeightChange(parent.minimumHeight)
                return
            }
            let used = layoutManager.usedRect(for: textContainer)
            let fullGlyphRange = NSRange(location: 0, length: glyphCount)
            let bound = layoutManager.boundingRect(forGlyphRange: fullGlyphRange, in: textContainer)
            let lineBottom = max(used.maxY, bound.maxY, used.minY + used.size.height, bound.minY + bound.size.height)
            let inset = textView.textContainerInset.height * 2
            let height = max(parent.minimumHeight, ceil(lineBottom + inset + 6))
            parent.onHeightChange(height)
        }
    }
}

private enum BlockTextCommand {
    case returnKey
    case backspaceAtStart
    case slash
}

private final class BlockNSTextView: NSTextView {
    var commandHandler: ((BlockTextCommand, BlockNSTextView) -> Bool)?
    var onBecameFirstResponder: (() -> Void)?
    var onWidthForLayoutChange: (() -> Void)?
    private var lastLayoutWidth: CGFloat = -1

    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok { onBecameFirstResponder?() }
        return ok
    }

    override func layout() {
        super.layout()
        let w = bounds.width
        if abs(w - lastLayoutWidth) > 0.5 {
            lastLayoutWidth = w
            if w > 1 {
                onWidthForLayoutChange?()
            }
        }
    }

    override func keyDown(with event: NSEvent) {
        let blockedModifiers: NSEvent.ModifierFlags = [.command, .control, .option]
        let canHandle = event.modifierFlags.intersection(blockedModifiers).isEmpty

        if canHandle, event.keyCode == 36 || event.keyCode == 76 {
            if commandHandler?(.returnKey, self) == true { return }
        }

        if canHandle, event.keyCode == 51, string.isEmpty, selectedRange().location == 0 {
            if commandHandler?(.backspaceAtStart, self) == true { return }
        }

        if canHandle, event.charactersIgnoringModifiers == "/" {
            if commandHandler?(.slash, self) == true { return }
        }

        super.keyDown(with: event)
    }
}
