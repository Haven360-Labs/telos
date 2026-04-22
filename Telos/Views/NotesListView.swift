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
                NotePageEditorView(note: note, modelContext: modelContext, onDismiss: {
                    selectedNote = nil
                })
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
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

struct NotePageEditorView: View {
    @Bindable var note: PlanNote
    var modelContext: ModelContext
    var onDismiss: () -> Void

    @State private var focusedBlockID: PersistentIdentifier?
    @State private var slashMenuBlockID: PersistentIdentifier?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    TextField("Untitled", text: $note.title, prompt: Text("Untitled"))
                        .font(.system(size: 30, weight: .bold))
                        .textFieldStyle(.plain)
                        .onSubmit { saveNoteChange() }
                        .onChange(of: note.title) { _, _ in saveNoteChange() }

                    Text(note.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(note.sortedBlocks) { block in
                            NoteBlockRow(
                                block: block,
                                isFocused: focusedBlockID == block.persistentModelID,
                                isShowingBlockMenu: Binding(
                                    get: { slashMenuBlockID == block.persistentModelID },
                                    set: { isShowing in
                                        if !isShowing {
                                            slashMenuBlockID = nil
                                        }
                                    }
                                ),
                                onTextChanged: saveNoteChange,
                                onReturn: { cursor in splitBlock(block, at: cursor) },
                                onBackspaceEmpty: { deleteEmptyBlock(block) },
                                onSlash: { slashMenuBlockID = block.persistentModelID },
                                onConvert: { kind in convert(block, to: kind) },
                                onDelete: { deleteBlock(block) }
                            )
                            .id(block.persistentModelID)
                        }

                        Button {
                            appendBlock(after: note.sortedBlocks.last)
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
        }
        .onAppear(perform: prepareBlocks)
        .onDisappear {
            note.rebuildContentCache()
            try? modelContext.save()
        }
    }

    private func prepareBlocks() {
        note.ensureBlocks(modelContext: modelContext)
        try? modelContext.save()
        if focusedBlockID == nil {
            focusedBlockID = note.sortedBlocks.first?.persistentModelID
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
        let newKind: PlanNoteBlockKind = block.kind == .heading ? .paragraph : block.kind

        block.text = before
        for following in note.sortedBlocks where following.sortOrder > block.sortOrder {
            following.sortOrder += 1
        }

        let newBlock = PlanNoteBlock(kind: newKind, text: after, sortOrder: block.sortOrder + 1, note: note)
        modelContext.insert(newBlock)
        note.blocks.append(newBlock)
        normalizeBlockOrder()
        note.rebuildContentCache()
        try? modelContext.save()
        focusedBlockID = newBlock.persistentModelID
    }

    private func appendBlock(after block: PlanNoteBlock?) {
        guard let block else {
            let newBlock = PlanNoteBlock(kind: .paragraph, sortOrder: 0, note: note)
            modelContext.insert(newBlock)
            note.blocks.append(newBlock)
            saveNoteChange()
            focusedBlockID = newBlock.persistentModelID
            return
        }
        for following in note.sortedBlocks where following.sortOrder > block.sortOrder {
            following.sortOrder += 1
        }
        let newBlock = PlanNoteBlock(kind: .paragraph, sortOrder: block.sortOrder + 1, note: note)
        modelContext.insert(newBlock)
        note.blocks.append(newBlock)
        normalizeBlockOrder()
        saveNoteChange()
        focusedBlockID = newBlock.persistentModelID
    }

    private func deleteEmptyBlock(_ block: PlanNoteBlock) {
        guard block.text.isEmpty else { return }
        deleteBlock(block)
    }

    private func deleteBlock(_ block: PlanNoteBlock) {
        let blocks = note.sortedBlocks
        guard blocks.count > 1 else {
            block.kind = .paragraph
            block.text = ""
            block.isChecked = false
            slashMenuBlockID = nil
            focusedBlockID = block.persistentModelID
            saveNoteChange()
            return
        }

        let index = blocks.firstIndex { $0.persistentModelID == block.persistentModelID } ?? 0
        let focusTarget = index > 0 ? blocks[index - 1] : blocks[min(index + 1, blocks.count - 1)]
        note.blocks.removeAll { $0.persistentModelID == block.persistentModelID }
        modelContext.delete(block)
        normalizeBlockOrder()
        slashMenuBlockID = nil
        note.rebuildContentCache()
        try? modelContext.save()
        focusedBlockID = focusTarget.persistentModelID
    }

    private func convert(_ block: PlanNoteBlock, to kind: PlanNoteBlockKind) {
        block.kind = kind
        if kind != .checklist {
            block.isChecked = false
        }
        slashMenuBlockID = nil
        focusedBlockID = block.persistentModelID
        saveNoteChange()
    }

    private func normalizeBlockOrder() {
        for (index, block) in note.sortedBlocks.enumerated() {
            block.sortOrder = index
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

    @State private var height: CGFloat = 28
    @State private var isHovering = false

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
                .frame(width: 24, height: minHeight, alignment: .top)

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
                    onHeightChange: { height = $0 }
                )
                .frame(minHeight: minHeight, maxHeight: max(height, minHeight))
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
        .onHover { hovering in
            isHovering = hovering
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
        textView.isVerticallyResizable = true
        textView.font = nsFont
        textView.string = text
        applyDynamicColors(to: textView)
        textView.commandHandler = context.coordinator.handle
        return textView
    }

    func updateNSView(_ textView: BlockNSTextView, context: Context) {
        context.coordinator.parent = self
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
            guard let layoutManager = textView.layoutManager,
                  let textContainer = textView.textContainer else {
                parent.onHeightChange(parent.minimumHeight)
                return
            }
            layoutManager.ensureLayout(for: textContainer)
            let usedRect = layoutManager.usedRect(for: textContainer)
            let height = max(parent.minimumHeight, ceil(usedRect.height + textView.textContainerInset.height * 2 + 4))
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
