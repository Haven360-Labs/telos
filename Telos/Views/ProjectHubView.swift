import SwiftUI
import SwiftData
import AppKit

private enum ProjectDetailSection: String, CaseIterable, Identifiable {
    case overview
    case notes
    case board
    case sprints
    case retrospectives
    case timeline
    case documents

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .notes: return "Notes"
        case .board: return "Board"
        case .sprints: return "Sprints"
        case .retrospectives: return "Retrospectives"
        case .timeline: return "Timeline"
        case .documents: return "Documents"
        }
    }

    var symbol: String {
        switch self {
        case .overview: return "rectangle.grid.1x2"
        case .notes: return "note.text"
        case .board: return "rectangle.split.3x1"
        case .sprints: return "calendar.badge.clock"
        case .retrospectives: return "arrow.triangle.2.circlepath"
        case .timeline: return "timeline.selection"
        case .documents: return "doc.richtext"
        }
    }
}

struct ProjectHubView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StreakStore.self) private var streakStore
    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]
    @State private var selectedProject: Project?
    @State private var section: ProjectDetailSection = .overview
    @State private var newProjectName = ""
    @State private var showNewProjectSheet = false

    var body: some View {
        Group {
            if let project = selectedProject {
                projectWorkspace(project)
            } else {
                projectList
            }
        }
        .navigationTitle(selectedProject == nil ? "Projects" : selectedProject!.name)
        .toolbar {
            if selectedProject == nil {
                ToolbarItem(placement: .primaryAction) {
                    Button("New project") {
                        newProjectName = ""
                        showNewProjectSheet = true
                    }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                }
            } else {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Projects") {
                        try? modelContext.save()
                        selectedProject = nil
                        section = .overview
                    }
                }
            }
        }
        .sheet(isPresented: $showNewProjectSheet) {
            newProjectSheet
        }
    }

    private var projectList: some View {
        Group {
            if projects.isEmpty {
                ContentUnavailableView(
                    "No projects yet",
                    systemImage: "folder.badge.plus",
                    description: Text("Create a project to organize notes, a board, sprints, and more.")
                )
            } else {
                List(selection: $selectedProject) {
                    ForEach(projects) { project in
                        Button {
                            selectedProject = project
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(project.name)
                                    .font(.headline)
                                Text(project.createdAt, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .tag(project)
                    }
                    .onDelete(perform: deleteProjects)
                }
                .listStyle(.inset)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func projectWorkspace(_ project: Project) -> some View {
        HStack(spacing: 0) {
            List(selection: $section) {
                ForEach(ProjectDetailSection.allCases) { sec in
                    Label(sec.title, systemImage: sec.symbol)
                        .tag(sec)
                }
            }
            .listStyle(.sidebar)
            .frame(width: 180)

            Divider()

            Group {
                switch section {
                case .overview:
                    ProjectOverviewSection(project: project, modelContext: modelContext)
                case .notes:
                    ProjectNotesSection(project: project, modelContext: modelContext, streakStore: streakStore)
                case .board:
                    ProjectBoardSection(project: project, modelContext: modelContext, streakStore: streakStore)
                case .sprints:
                    ProjectSprintsSection(project: project, modelContext: modelContext, streakStore: streakStore)
                case .retrospectives:
                    ProjectRetrospectivesSection(project: project, modelContext: modelContext, streakStore: streakStore)
                case .timeline:
                    ProjectTimelineSection(project: project, modelContext: modelContext, streakStore: streakStore)
                case .documents:
                    ProjectDocumentsSection(project: project, modelContext: modelContext, streakStore: streakStore)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            ProjectBoardDefaults.ensureDefaultColumns(for: project, modelContext: modelContext)
            try? modelContext.save()
        }
    }

    private var newProjectSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New project")
                .font(.headline)
            TextField("Name", text: $newProjectName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel") { showNewProjectSheet = false }
                Button("Create") {
                    let name = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { return }
                    let project = Project(name: name)
                    modelContext.insert(project)
                    ProjectBoardDefaults.ensureDefaultColumns(for: project, modelContext: modelContext)
                    try? modelContext.save()
                    streakStore.recordUsage()
                    selectedProject = project
                    showNewProjectSheet = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(minWidth: 320)
    }

    private func deleteProjects(at offsets: IndexSet) {
        for index in offsets {
            let p = projects[index]
            if selectedProject?.id == p.id {
                selectedProject = nil
            }
            modelContext.delete(p)
        }
        try? modelContext.save()
        streakStore.recordUsage()
    }
}

// MARK: - Overview

private struct ProjectOverviewSection: View {
    @Bindable var project: Project
    var modelContext: ModelContext

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                TextField("Project name", text: $project.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { try? modelContext.save() }

                Text("Created \(project.createdAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    statTile(title: "Notes", value: "\(project.notes.count)", symbol: "note.text")
                    statTile(title: "Board cards", value: "\(cardCount)", symbol: "rectangle.split.3x1")
                    statTile(title: "Sprints", value: "\(project.sprints.count)", symbol: "calendar.badge.clock")
                    statTile(title: "Documents", value: "\(project.documents.count)", symbol: "doc.richtext")
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var cardCount: Int {
        project.kanbanColumns.reduce(0) { $0 + $1.cards.count }
    }

    private func statTile(title: String, value: String, symbol: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.medium)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Notes

private struct ProjectNotesSection: View {
    var project: Project
    var modelContext: ModelContext
    var streakStore: StreakStore

    @State private var showAddNote = false
    @State private var newTitle = ""
    @State private var newContent = ""
    @State private var selectedNote: PlanNote?

    private var projectNotes: [PlanNote] {
        project.notes.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        Group {
            if showAddNote {
                AddNoteScreen(
                    title: $newTitle,
                    content: $newContent,
                    onSave: {
                        addNote()
                        showAddNote = false
                    },
                    onCancel: {
                        newTitle = ""
                        newContent = ""
                        showAddNote = false
                    }
                )
            } else if let note = selectedNote {
                NoteDetailView(note: note, modelContext: modelContext, onDismiss: {
                    selectedNote = nil
                })
            } else {
                List(selection: $selectedNote) {
                    ForEach(projectNotes) { note in
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
                            Button("Delete", role: .destructive) {
                                deleteNote(note)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .toolbar {
            if showAddNote {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        newTitle = ""
                        newContent = ""
                        showAddNote = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        addNote()
                        showAddNote = false
                    }
                    .disabled(newContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } else if selectedNote != nil {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        try? modelContext.save()
                        selectedNote = nil
                    }
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
                        newTitle = ""
                        newContent = ""
                        showAddNote = true
                    }
                }
            }
        }
    }

    private func addNote() {
        let content = newContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let note = PlanNote(title: title, content: content, project: project)
        modelContext.insert(note)
        project.notes.append(note)
        try? modelContext.save()
        streakStore.recordUsage()
        newTitle = ""
        newContent = ""
    }

    private func deleteNote(_ note: PlanNote) {
        if selectedNote?.id == note.id { selectedNote = nil }
        modelContext.delete(note)
        try? modelContext.save()
        streakStore.recordUsage()
    }
}

// MARK: - Board

private struct ProjectBoardSection: View {
    var project: Project
    var modelContext: ModelContext
    var streakStore: StreakStore

    @State private var cardToEdit: ProjectKanbanCard?
    @State private var newCardTitle = ""
    @State private var newCardBody = ""
    @State private var addCardColumn: ProjectKanbanColumn?

    private var sortedColumns: [ProjectKanbanColumn] {
        project.kanbanColumns.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(sortedColumns) { column in
                    boardColumn(column)
                }
            }
            .padding(16)
        }
        .sheet(item: $addCardColumn) { column in
            newCardSheet(column: column)
        }
        .sheet(item: $cardToEdit) { card in
            editCardSheet(card: card)
        }
    }

    private func boardColumn(_ column: ProjectKanbanColumn) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(column.title)
                .font(.headline)
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(column.sortedCards) { card in
                        boardCardRow(card, column: column)
                    }
                }
            }
            .frame(minWidth: 220, maxWidth: 280, maxHeight: .infinity)

            Button {
                newCardTitle = ""
                newCardBody = ""
                addCardColumn = column
            } label: {
                Label("Add card", systemImage: "plus.circle")
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .frame(minHeight: 360, alignment: .topLeading)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
    }

    private func boardCardRow(_ card: ProjectKanbanCard, column: ProjectKanbanColumn) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(card.title.isEmpty ? "Untitled" : card.title)
                .font(.subheadline)
                .fontWeight(.medium)
            if !card.body.isEmpty {
                Text(card.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            Menu {
                ForEach(sortedColumns.filter { $0.id != column.id }) { other in
                    Button("Move to \(other.title)") {
                        moveCard(card, to: other)
                    }
                }
                Divider()
                Button("Edit…") {
                    cardToEdit = card
                }
                Button("Delete", role: .destructive) {
                    modelContext.delete(card)
                    try? modelContext.save()
                    streakStore.recordUsage()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
    }

    private func moveCard(_ card: ProjectKanbanCard, to column: ProjectKanbanColumn) {
        card.column = column
        let nextOrder = (column.cards.map(\.sortOrder).max() ?? -1) + 1
        card.sortOrder = nextOrder
        try? modelContext.save()
        streakStore.recordUsage()
    }

    private func newCardSheet(column: ProjectKanbanColumn) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New card")
                .font(.headline)
            TextField("Title", text: $newCardTitle)
                .textFieldStyle(.roundedBorder)
            TextEditor(text: $newCardBody)
                .font(.body)
                .frame(height: 100)
                .padding(8)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
            HStack {
                Spacer()
                Button("Cancel") { addCardColumn = nil }
                Button("Add") {
                    let title = newCardTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !title.isEmpty else { return }
                    let nextOrder = (column.cards.map(\.sortOrder).max() ?? -1) + 1
                    let card = ProjectKanbanCard(title: title, body: newCardBody, sortOrder: nextOrder, column: column)
                    modelContext.insert(card)
                    column.cards.append(card)
                    try? modelContext.save()
                    streakStore.recordUsage()
                    addCardColumn = nil
                }
                .keyboardShortcut(.defaultAction)
                .disabled(newCardTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 320)
    }

    private func editCardSheet(card: ProjectKanbanCard) -> some View {
        EditKanbanCardSheet(card: card, onDismiss: {
            cardToEdit = nil
            try? modelContext.save()
            streakStore.recordUsage()
        })
    }
}

private struct EditKanbanCardSheet: View {
    @Bindable var card: ProjectKanbanCard
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Edit card")
                .font(.headline)
            TextField("Title", text: $card.title)
                .textFieldStyle(.roundedBorder)
            TextEditor(text: $card.body)
                .font(.body)
                .frame(height: 120)
                .padding(8)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
            HStack {
                Spacer()
                Button("Done") { onDismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 320)
    }
}

// MARK: - Sprints

private struct ProjectSprintsSection: View {
    var project: Project
    var modelContext: ModelContext
    var streakStore: StreakStore

    @State private var showAdd = false
    @State private var title = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .day, value: 14, to: Date()) ?? Date()
    @State private var notes = ""
    @State private var selected: ProjectSprint?

    private var sortedSprints: [ProjectSprint] {
        project.sprints.sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        Group {
            if let sprint = selected {
                SprintEditorView(sprint: sprint, modelContext: modelContext)
            } else {
                List(selection: $selected) {
                    ForEach(sortedSprints) { sprint in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(sprint.title)
                                .font(.headline)
                            Text("\(sprint.startDate.formatted(date: .abbreviated, time: .omitted)) – \(sprint.endDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(sprint)
                    }
                    .onDelete(perform: deleteSprints)
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $showAdd) {
            VStack(alignment: .leading, spacing: 14) {
                Text("New sprint")
                    .font(.headline)
                TextField("Title", text: $title)
                    .textFieldStyle(.roundedBorder)
                DatePicker("Start", selection: $startDate, displayedComponents: .date)
                DatePicker("End", selection: $endDate, displayedComponents: .date)
                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Spacer()
                    Button("Cancel") { showAdd = false }
                    Button("Create") {
                        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !t.isEmpty else { return }
                        let start = Calendar.current.startOfDay(for: startDate)
                        let end = Calendar.current.startOfDay(for: endDate)
                        guard start <= end else { return }
                        let sprint = ProjectSprint(title: t, startDate: start, endDate: end, notes: notes, project: project)
                        modelContext.insert(sprint)
                        project.sprints.append(sprint)
                        try? modelContext.save()
                        streakStore.recordUsage()
                        showAdd = false
                        title = ""
                        notes = ""
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(20)
            .frame(minWidth: 340)
        }
        .toolbar {
            if selected == nil {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add sprint") { showAdd = true }
                }
            } else {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        try? modelContext.save()
                        selected = nil
                    }
                }
            }
        }
    }

    private func deleteSprints(at offsets: IndexSet) {
        for index in offsets {
            let s = sortedSprints[index]
            if selected?.id == s.id { selected = nil }
            modelContext.delete(s)
        }
        try? modelContext.save()
        streakStore.recordUsage()
    }
}

// MARK: - Retrospectives

private struct ProjectRetrospectivesSection: View {
    var project: Project
    var modelContext: ModelContext
    var streakStore: StreakStore

    @State private var showAdd = false
    @State private var notes = ""
    @State private var sprintPick: ProjectSprint?
    @State private var selected: ProjectRetrospective?

    private var sortedRetros: [ProjectRetrospective] {
        project.retrospectives.sorted { $0.createdAt > $1.createdAt }
    }

    private var sortedSprints: [ProjectSprint] {
        project.sprints.sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        Group {
            if let retro = selected {
                RetroEditorView(retro: retro, modelContext: modelContext)
            } else {
                List(selection: $selected) {
                    ForEach(sortedRetros) { retro in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(retro.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.headline)
                            if let s = retro.sprint {
                                Text(s.title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(retro)
                    }
                    .onDelete(perform: deleteRetros)
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $showAdd) {
            VStack(alignment: .leading, spacing: 14) {
                Text("New retrospective")
                    .font(.headline)
                Picker("Sprint", selection: $sprintPick) {
                    Text("None").tag(nil as ProjectSprint?)
                    ForEach(sortedSprints) { s in
                        Text(s.title).tag(s as ProjectSprint?)
                    }
                }
                TextEditor(text: $notes)
                    .frame(height: 140)
                    .padding(8)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                HStack {
                    Spacer()
                    Button("Cancel") {
                        showAdd = false
                        notes = ""
                    }
                    Button("Save") {
                        let retro = ProjectRetrospective(notes: notes, project: project, sprint: sprintPick)
                        modelContext.insert(retro)
                        project.retrospectives.append(retro)
                        try? modelContext.save()
                        streakStore.recordUsage()
                        showAdd = false
                        notes = ""
                        sprintPick = nil
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(minWidth: 360)
        }
        .toolbar {
            if selected == nil {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add retrospective") { showAdd = true }
                }
            } else {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        try? modelContext.save()
                        selected = nil
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Delete", role: .destructive) {
                        if let r = selected {
                            modelContext.delete(r)
                            try? modelContext.save()
                            selected = nil
                            streakStore.recordUsage()
                        }
                    }
                }
            }
        }
    }

    private func deleteRetros(at offsets: IndexSet) {
        for index in offsets {
            let r = sortedRetros[index]
            if selected?.id == r.id { selected = nil }
            modelContext.delete(r)
        }
        try? modelContext.save()
        streakStore.recordUsage()
    }
}

// MARK: - Timeline

private struct ProjectTimelineSection: View {
    var project: Project
    var modelContext: ModelContext
    var streakStore: StreakStore

    @State private var showAdd = false
    @State private var title = ""
    @State private var startDate = Date()
    @State private var hasEnd = false
    @State private var endDate = Date()
    @State private var detail = ""
    @State private var selected: ProjectTimelineEvent?

    private var sortedEvents: [ProjectTimelineEvent] {
        project.timelineEvents.sorted { e1, e2 in
            if e1.startDate != e2.startDate { return e1.startDate < e2.startDate }
            return e1.sortOrder < e2.sortOrder
        }
    }

    var body: some View {
        Group {
            if let ev = selected {
                TimelineEventEditorView(event: ev, modelContext: modelContext)
            } else {
                List(selection: $selected) {
                    ForEach(sortedEvents) { event in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.title)
                                .font(.headline)
                            Text(event.startDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(event)
                    }
                    .onDelete(perform: deleteEvents)
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $showAdd) {
            VStack(alignment: .leading, spacing: 14) {
                Text("New timeline event")
                    .font(.headline)
                TextField("Title", text: $title)
                    .textFieldStyle(.roundedBorder)
                DatePicker("Start", selection: $startDate, displayedComponents: .date)
                Toggle("End date", isOn: $hasEnd)
                if hasEnd {
                    DatePicker("End", selection: $endDate, displayedComponents: .date)
                }
                TextField("Details", text: $detail, axis: .vertical)
                    .lineLimit(2...5)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Spacer()
                    Button("Cancel") { showAdd = false }
                    Button("Add") {
                        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !t.isEmpty else { return }
                        let nextOrder = (project.timelineEvents.map(\.sortOrder).max() ?? -1) + 1
                        let end: Date? = hasEnd ? Calendar.current.startOfDay(for: endDate) : nil
                        let start = Calendar.current.startOfDay(for: startDate)
                        if let e = end, e < start { return }
                        let event = ProjectTimelineEvent(
                            title: t,
                            startDate: start,
                            endDate: end,
                            detail: detail,
                            sortOrder: nextOrder,
                            project: project
                        )
                        modelContext.insert(event)
                        project.timelineEvents.append(event)
                        try? modelContext.save()
                        streakStore.recordUsage()
                        showAdd = false
                        title = ""
                        detail = ""
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding(20)
            .frame(minWidth: 340)
        }
        .toolbar {
            if selected == nil {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add event") { showAdd = true }
                }
            } else {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        try? modelContext.save()
                        selected = nil
                    }
                }
            }
        }
    }

    private func deleteEvents(at offsets: IndexSet) {
        for index in offsets {
            let e = sortedEvents[index]
            if selected?.id == e.id { selected = nil }
            modelContext.delete(e)
        }
        try? modelContext.save()
        streakStore.recordUsage()
    }
}

// MARK: - Documents

private struct ProjectDocumentsSection: View {
    var project: Project
    var modelContext: ModelContext
    var streakStore: StreakStore

    var body: some View {
        let sortedDocs = project.documents.sorted { $0.addedAt > $1.addedAt }
        List {
            ForEach(sortedDocs) { doc in
                HStack {
                    Image(systemName: "doc.fill")
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(doc.displayName)
                        Text(doc.addedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Button("Open") {
                        openDocument(doc)
                    }
                    .buttonStyle(.bordered)
                    Button("Reveal") {
                        revealDocument(doc)
                    }
                    .buttonStyle(.bordered)
                }
                .contextMenu {
                    Button("Remove", role: .destructive) {
                        modelContext.delete(doc)
                        try? modelContext.save()
                        streakStore.recordUsage()
                    }
                }
            }
        }
        .listStyle(.inset)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Add document") {
                    addDocument()
                }
            }
        }
    }

    private func addDocument() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.prompt = "Add"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            let name = url.lastPathComponent
            let doc = ProjectDocument(displayName: name, bookmarkData: data, project: project)
            modelContext.insert(doc)
            project.documents.append(doc)
            try? modelContext.save()
            streakStore.recordUsage()
        } catch {
            // Bookmark failed; skip
        }
    }

    private func resolvedURL(for doc: ProjectDocument) -> URL? {
        var stale = false
        return try? URL(
            resolvingBookmarkData: doc.bookmarkData,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
    }

    private func openDocument(_ doc: ProjectDocument) {
        guard let url = resolvedURL(for: doc) else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        NSWorkspace.shared.open(url)
    }

    private func revealDocument(_ doc: ProjectDocument) {
        guard let url = resolvedURL(for: doc) else { return }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
}

// MARK: - Detail editors (Bindable models)

private struct SprintEditorView: View {
    @Bindable var sprint: ProjectSprint
    var modelContext: ModelContext

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Title", text: $sprint.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .textFieldStyle(.roundedBorder)
                DatePicker("Start", selection: $sprint.startDate, displayedComponents: .date)
                DatePicker("End", selection: $sprint.endDate, displayedComponents: .date)
                Text("Notes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $sprint.notes)
                    .font(.body)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .onDisappear { try? modelContext.save() }
    }
}

private struct RetroEditorView: View {
    @Bindable var retro: ProjectRetrospective
    var modelContext: ModelContext

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(retro.createdAt.formatted(date: .long, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let s = retro.sprint {
                    Text("Sprint: \(s.title)")
                        .font(.subheadline)
                }
                TextEditor(text: $retro.notes)
                    .font(.body)
                    .frame(minHeight: 200)
                    .padding(10)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .onDisappear { try? modelContext.save() }
    }
}

private struct TimelineEventEditorView: View {
    @Bindable var event: ProjectTimelineEvent
    var modelContext: ModelContext
    @State private var hasEndDate: Bool

    init(event: ProjectTimelineEvent, modelContext: ModelContext) {
        self.event = event
        self.modelContext = modelContext
        _hasEndDate = State(initialValue: event.endDate != nil)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                TextField("Title", text: $event.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .textFieldStyle(.roundedBorder)
                DatePicker("Start", selection: $event.startDate, displayedComponents: .date)
                Toggle("End date", isOn: $hasEndDate)
                    .onChange(of: hasEndDate) { _, on in
                        if !on {
                            event.endDate = nil
                        } else if event.endDate == nil {
                            event.endDate = event.startDate
                        }
                    }
                if hasEndDate {
                    DatePicker(
                        "End",
                        selection: Binding(
                            get: { event.endDate ?? event.startDate },
                            set: { event.endDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                }
                TextEditor(text: $event.detail)
                    .font(.body)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10))
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .onDisappear { try? modelContext.save() }
    }
}
