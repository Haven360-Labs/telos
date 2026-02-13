import SwiftUI
import SwiftData

struct NotesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StreakStore.self) private var streakStore
    @Query(sort: \PlanNote.createdAt, order: .reverse) private var notes: [PlanNote]
    @State private var showAddNote = false
    @State private var newNoteContent = ""
    @State private var selectedNote: PlanNote?

    var body: some View {
        List(selection: $selectedNote) {
            ForEach(notes) { note in
                Button {
                    selectedNote = note
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.preview)
                            .lineLimit(2)
                            .foregroundStyle(.primary)
                        Text(note.createdAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.inset)
        .navigationTitle("Notes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add note") {
                    newNoteContent = ""
                    showAddNote = true
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
        }
        .sheet(isPresented: $showAddNote) {
            AddNoteView(content: $newNoteContent) {
                addNote()
                showAddNote = false
            }
            .frame(minWidth: 400, minHeight: 200)
            .presentationCornerRadius(12)
        }
        .sheet(item: $selectedNote) { note in
            NoteDetailView(note: note, modelContext: modelContext)
                .presentationCornerRadius(12)
        }
    }

    private func addNote() {
        let content = newNoteContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        let note = PlanNote(content: content)
        modelContext.insert(note)
        try? modelContext.save()
        streakStore.recordUsage()
    }
}

struct AddNoteView: View {
    @Binding var content: String
    var onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New note")
                .font(.headline)
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

struct NoteDetailView: View {
    @Bindable var note: PlanNote
    var modelContext: ModelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(note.createdAt, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $note.content)
                .font(.body)
        }
        .padding()
        .frame(minWidth: 400, minHeight: 300)
        .onDisappear { try? modelContext.save() }
    }
}
