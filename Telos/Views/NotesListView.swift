import SwiftUI
import SwiftData

struct NotesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StreakStore.self) private var streakStore
    @Query(sort: \PlanNote.createdAt, order: .reverse) private var notes: [PlanNote]
    @State private var showAddNote = false
    @State private var newNoteTitle = ""
    @State private var newNoteContent = ""
    @State private var selectedNote: PlanNote?

    var body: some View {
        Group {
            if showAddNote {
                AddNoteScreen(
                    title: $newNoteTitle,
                    content: $newNoteContent,
                    onSave: {
                        addNote()
                        showAddNote = false
                    },
                    onCancel: {
                        newNoteTitle = ""
                        newNoteContent = ""
                        showAddNote = false
                    }
                )
            } else if let note = selectedNote {
                NoteDetailView(note: note, modelContext: modelContext, onDismiss: {
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
        .navigationTitle(showAddNote ? "New note" : (selectedNote != nil ? "Note" : "Notes"))
        .toolbar {
            if showAddNote {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        newNoteTitle = ""
                        newNoteContent = ""
                        showAddNote = false
                    }
                    .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        addNote()
                        showAddNote = false
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(newNoteContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } else if selectedNote != nil {
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
                            modelContext.delete(note)
                            try? modelContext.save()
                            selectedNote = nil
                        }
                    }
                }
            } else {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add note") {
                        newNoteTitle = ""
                        newNoteContent = ""
                        showAddNote = true
                    }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                }
            }
        }
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

    private func addNote() {
        let content = newNoteContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        let title = newNoteTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = PlanNote(title: title, content: content)
        modelContext.insert(note)
        try? modelContext.save()
        streakStore.recordUsage()
        newNoteTitle = ""
        newNoteContent = ""
    }
}

/// Full-space screen for creating a new note (replaces list content, no modal).
struct AddNoteScreen: View {
    @Binding var title: String
    @Binding var content: String
    var onSave: () -> Void
    var onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Title", text: $title, prompt: Text("Note title"))
                    .font(.title2)
                    .fontWeight(.medium)
                    .textFieldStyle(.roundedBorder)
                TextEditor(text: $content)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial.opacity(0.3))
    }
}

/// Compact view for modal/sheet use (e.g. quick add from toolbar).
struct AddNoteView: View {
    @Binding var title: String
    @Binding var content: String
    var onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New note")
                .font(.headline)
            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)
            TextEditor(text: $content)
                .font(.body)
                .padding(8)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            HStack {
                Spacer()
                Button("Save") { onSave() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
    }
}

/// Full-space note editor (replaces list content, no modal). Save on Done or onDisappear.
struct NoteDetailView: View {
    @Bindable var note: PlanNote
    var modelContext: ModelContext
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Title", text: $note.title, prompt: Text("Note title"))
                    .font(.title2)
                    .fontWeight(.medium)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        try? modelContext.save()
                        onDismiss()
                    }
                Text(note.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $note.content)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial.opacity(0.3))
        .onDisappear { try? modelContext.save() }
    }
}
