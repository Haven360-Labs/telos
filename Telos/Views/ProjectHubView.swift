import SwiftUI
import SwiftData
import AppKit

private enum ProjectDetailSection: String, CaseIterable, Identifiable {
    case overview
    case roadmap
    case milestones
    case boardAndTasks
    case notes
    case sprints
    case retrospectives
    case timeline
    case releases
    case testing
    case documents

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .roadmap: return "Roadmap"
        case .milestones: return "Milestones"
        case .boardAndTasks: return "Board & tasks"
        case .notes: return "Notes"
        case .sprints: return "Sprints"
        case .retrospectives: return "Retrospectives"
        case .timeline: return "Timeline"
        case .releases: return "Releases"
        case .testing: return "Testing"
        case .documents: return "Documents"
        }
    }

    var symbol: String {
        switch self {
        case .overview: return "rectangle.grid.1x2"
        case .roadmap: return "map"
        case .milestones: return "flag.checkered"
        case .boardAndTasks: return "rectangle.split.3x1"
        case .notes: return "note.text"
        case .sprints: return "calendar.badge.clock"
        case .retrospectives: return "arrow.triangle.2.circlepath"
        case .timeline: return "timeline.selection"
        case .releases: return "shippingbox"
        case .testing: return "checklist"
        case .documents: return "doc.richtext"
        }
    }
}

struct ProjectHubView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StreakStore.self) private var streakStore
    @Query(sort: \Project.createdAt, order: .reverse) private var allProjects: [Project]
    @State private var selectedProject: Project?
    @State private var section: ProjectDetailSection = .overview
    @State private var newProjectName = ""
    @State private var showNewProjectSheet = false
    @State private var showArchivedProjects = false
    @State private var projectPendingDeletion: Project?

    private var visibleProjects: [Project] {
        allProjects.filter { showArchivedProjects || !$0.isArchived }
    }

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
                ToolbarItem(placement: .automatic) {
                    Button {
                        showArchivedProjects.toggle()
                    } label: {
                        Label(
                            showArchivedProjects ? "Hide archived" : "Show archived",
                            systemImage: showArchivedProjects ? "archivebox.fill" : "archivebox"
                        )
                    }
                    .help(showArchivedProjects ? "Hide archived projects" : "Show archived projects")
                }
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
                ToolbarItem(placement: .primaryAction) {
                    if let project = selectedProject {
                        Menu {
                            if project.isArchived {
                                Button("Unarchive project") {
                                    setProjectArchived(project, archived: false)
                                }
                            } else {
                                Button("Archive project") {
                                    setProjectArchived(project, archived: true)
                                }
                            }
                            Divider()
                            Button("Delete project…", role: .destructive) {
                                projectPendingDeletion = project
                            }
                        } label: {
                            Label("Project options", systemImage: "ellipsis.circle")
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            "Delete this project?",
            isPresented: Binding(
                get: { projectPendingDeletion != nil },
                set: { if !$0 { projectPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete project and all of its data", role: .destructive) {
                if let project = projectPendingDeletion {
                    deleteProjectPermanently(project)
                }
                projectPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                projectPendingDeletion = nil
            }
        } message: {
            if let project = projectPendingDeletion {
                Text("“\(project.name)” and everything inside it (notes, board & tasks, sprints, retrospectives, timeline, roadmap, releases, and other project data) will be permanently removed.")
            }
        }
        .sheet(isPresented: $showNewProjectSheet) {
            newProjectSheet
        }
    }

    private var projectList: some View {
        Group {
            if visibleProjects.isEmpty {
                ContentUnavailableView(
                    allProjects.isEmpty ? "No projects yet" : "No active projects",
                    systemImage: "folder.badge.plus",
                    description: Text(
                        allProjects.isEmpty
                            ? "Create a project to organize notes, a board, sprints, and more."
                            : "Turn on “Show archived” to see archived projects, or create a new one."
                    )
                )
            } else {
                List(selection: $selectedProject) {
                    ForEach(visibleProjects) { project in
                        Button {
                            selectedProject = project
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(project.name)
                                        .font(.headline)
                                    if project.isArchived {
                                        Text("Archived")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.quaternary, in: Capsule())
                                    }
                                }
                                Text(project.createdAt, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .tag(project)
                        .contextMenu {
                            if project.isArchived {
                                Button("Unarchive project") {
                                    setProjectArchived(project, archived: false)
                                }
                            } else {
                                Button("Archive project") {
                                    setProjectArchived(project, archived: true)
                                }
                            }
                            Divider()
                            Button("Delete project…", role: .destructive) {
                                projectPendingDeletion = project
                            }
                        }
                    }
                    .onDelete(perform: deleteProjectsAtOffsets)
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
            .frame(minWidth: 200, idealWidth: 220, maxWidth: 260)

            Divider()

            Group {
                switch section {
                case .overview:
                    ProjectOverviewSection(project: project, modelContext: modelContext, streakStore: streakStore)
                case .roadmap:
                    ProjectRoadmapHubSection(project: project, modelContext: modelContext, streakStore: streakStore)
                case .milestones:
                    ProjectMilestonesHubSection(project: project, modelContext: modelContext, streakStore: streakStore)
                case .boardAndTasks:
                    ProjectBoardAndTasksSection(project: project, modelContext: modelContext, streakStore: streakStore)
                case .notes:
                    ProjectNotesSection(project: project, modelContext: modelContext, streakStore: streakStore)
                case .sprints:
                    ProjectSprintsSection(project: project, modelContext: modelContext, streakStore: streakStore)
                case .retrospectives:
                    ProjectRetrospectivesSection(project: project, modelContext: modelContext, streakStore: streakStore)
                case .timeline:
                    ProjectTimelineSection(project: project, modelContext: modelContext, streakStore: streakStore)
                case .releases:
                    ProjectReleasesHubSection(project: project, modelContext: modelContext, streakStore: streakStore)
                case .testing:
                    ProjectTestingHubSection(project: project, modelContext: modelContext, streakStore: streakStore)
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

    /// List swipe/delete key: confirm if single row, otherwise delete immediately.
    private func deleteProjectsAtOffsets(_ offsets: IndexSet) {
        if offsets.count == 1, let index = offsets.first {
            projectPendingDeletion = visibleProjects[index]
            return
        }
        for index in offsets {
            let p = visibleProjects[index]
            if selectedProject?.persistentModelID == p.persistentModelID {
                selectedProject = nil
            }
            modelContext.delete(p)
        }
        try? modelContext.save()
        streakStore.recordUsage()
    }

    private func setProjectArchived(_ project: Project, archived: Bool) {
        project.isArchived = archived
        project.archivedAt = archived ? Date() : nil
        if archived, selectedProject?.persistentModelID == project.persistentModelID, !showArchivedProjects {
            selectedProject = nil
            section = .overview
        }
        try? modelContext.save()
        streakStore.recordUsage()
    }

    private func deleteProjectPermanently(_ project: Project) {
        if selectedProject?.persistentModelID == project.persistentModelID {
            selectedProject = nil
            section = .overview
        }
        modelContext.delete(project)
        try? modelContext.save()
        streakStore.recordUsage()
    }
}

// MARK: - Overview

private struct ProjectOverviewSection: View {
    @Bindable var project: Project
    var modelContext: ModelContext
    var streakStore: StreakStore

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

                if project.isArchived {
                    HStack(alignment: .center, spacing: 12) {
                        Label("This project is archived", systemImage: "archivebox.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                        Button("Unarchive") {
                            project.isArchived = false
                            project.archivedAt = nil
                            try? modelContext.save()
                            streakStore.recordUsage()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    statTile(title: "Notes", value: "\(project.notes.count)", symbol: "note.text")
                    statTile(title: "Board cards", value: "\(cardCount)", symbol: "rectangle.split.3x1")
                    statTile(title: "Milestones", value: "\(project.milestones.count)", symbol: "flag.checkered")
                    statTile(title: "Releases", value: "\(project.releases.count)", symbol: "shippingbox")
                    statTile(title: "Open tasks", value: "\(openIssueCount)", symbol: "checkmark.circle")
                    statTile(title: "Sprints", value: "\(project.sprints.count)", symbol: "calendar.badge.clock")
                    statTile(title: "Documents", value: "\(project.documents.count)", symbol: "doc.richtext")
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var cardCount: Int {
        project.kanbanColumns.filter { $0.sprint == nil }.reduce(0) { $0 + $1.cards.count }
    }

    /// Main-board kanban cards not in a column titled “Done” (same notion as “open tasks” as the board).
    private var openIssueCount: Int {
        let mainCols = project.kanbanColumns.filter { $0.sprint == nil }
        return mainCols.flatMap(\.cards).filter { card in
            guard let col = card.column else { return true }
            return col.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != "done"
        }.count
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
        if selectedNote?.persistentModelID == note.persistentModelID { selectedNote = nil }
        modelContext.delete(note)
        try? modelContext.save()
        streakStore.recordUsage()
    }
}

// MARK: - Board

/// Shared kanban UI for the project main board or a sprint board.
private struct KanbanBoardSection: View {
    var columns: [ProjectKanbanColumn]
    /// Project whose milestones appear in the card inspector (optional milestone link).
    var project: Project?
    var modelContext: ModelContext
    var streakStore: StreakStore

    @State private var cardForInspector: ProjectKanbanCard?
    @State private var newCardTitle = ""
    @State private var newCardBody = ""
    @State private var addCardColumn: ProjectKanbanColumn?
    @State private var dropTargetCardID: PersistentIdentifier?
    @State private var dropTargetColumnEndID: PersistentIdentifier?

    private var sortedColumns: [ProjectKanbanColumn] {
        columns.sorted { $0.sortOrder < $1.sortOrder }
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
        .sheet(item: $cardForInspector) { card in
            KanbanCardInspectorSheet(
                card: card,
                project: project,
                columnsForMove: sortedColumns,
                modelContext: modelContext,
                streakStore: streakStore,
                onDismiss: { cardForInspector = nil }
            )
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
                    columnEndDropZone(column)
                }
            }
            .frame(minWidth: 220, maxWidth: 280, maxHeight: .infinity)

            Button {
                newCardTitle = ""
                newCardBody = ""
                addCardColumn = column
            } label: {
                Label("Add task", systemImage: "plus.circle")
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .frame(minHeight: 360, alignment: .topLeading)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
    }

    private func columnEndDropZone(_ column: ProjectKanbanColumn) -> some View {
        let isTargeted = dropTargetColumnEndID == column.persistentModelID
        return Color.clear
            .frame(minHeight: 36)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .overlay {
                if isTargeted {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.secondary, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                }
            }
            .dropDestination(for: KanbanCardDragPayload.self) { items, _ in
                handleCardDrop(items: items, column: column, before: nil)
            } isTargeted: { targeted in
                if targeted {
                    dropTargetColumnEndID = column.persistentModelID
                } else if dropTargetColumnEndID == column.persistentModelID {
                    dropTargetColumnEndID = nil
                }
            }
            .help("Drop here to move to the bottom of this column")
    }

    private func boardCardRow(_ card: ProjectKanbanCard, column: ProjectKanbanColumn) -> some View {
        let isDropBefore = dropTargetCardID == card.persistentModelID
        return VStack(alignment: .leading, spacing: 6) {
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
                ForEach(sortedColumns.filter { $0.persistentModelID != column.persistentModelID }) { other in
                    Button("Move to \(other.title)") {
                        moveCard(card, to: other)
                    }
                }
                Divider()
                Button("Edit card…") {
                    cardForInspector = card
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
        .overlay(alignment: .top) {
            if isDropBefore {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(height: 3)
                    .padding(.horizontal, 4)
            }
        }
        .draggable(KanbanCardDragPayload(card: card)) {
            cardDragPreview(card)
        }
        .dropDestination(for: KanbanCardDragPayload.self) { items, _ in
            handleCardDrop(items: items, column: column, before: card)
        } isTargeted: { targeted in
            if targeted {
                dropTargetCardID = card.persistentModelID
            } else if dropTargetCardID == card.persistentModelID {
                dropTargetCardID = nil
            }
        }
        .help("Drag to reorder within the column or move to another column")
    }

    private func cardDragPreview(_ card: ProjectKanbanCard) -> some View {
        Text(card.title.isEmpty ? "Card" : card.title)
            .font(.subheadline)
            .fontWeight(.medium)
            .lineLimit(2)
            .padding(10)
            .frame(minWidth: 120, maxWidth: 200)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .shadow(radius: 4)
    }

    private func handleCardDrop(items: [KanbanCardDragPayload], column: ProjectKanbanColumn, before targetCard: ProjectKanbanCard?) -> Bool {
        guard let payload = items.first,
              let dragged = KanbanBoardDragSupport.card(for: payload, modelContext: modelContext) else { return false }
        withAnimation(.default) {
            KanbanBoardDragSupport.drop(dragged: dragged, targetColumn: column, before: targetCard, modelContext: modelContext)
        }
        streakStore.recordUsage()
        return true
    }

    private func moveCard(_ card: ProjectKanbanCard, to column: ProjectKanbanColumn) {
        KanbanBoardDragSupport.drop(dragged: card, targetColumn: column, before: nil, modelContext: modelContext)
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

}

private enum ProjectWorkHubTab: String, CaseIterable, Identifiable {
    case board = "Board"
    case tasks = "Tasks"
    var id: String { rawValue }
}

/// Single hub for the main kanban board and the task list (same `ProjectKanbanCard` data).
private struct ProjectBoardAndTasksSection: View {
    var project: Project
    var modelContext: ModelContext
    var streakStore: StreakStore

    @State private var tab: ProjectWorkHubTab = .board

    var body: some View {
        VStack(spacing: 0) {
            Picker("Board or tasks", selection: $tab) {
                ForEach(ProjectWorkHubTab.allCases) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Group {
                switch tab {
                case .board:
                    ProjectBoardSection(project: project, modelContext: modelContext, streakStore: streakStore)
                case .tasks:
                    ProjectMainBoardTaskListSection(project: project, modelContext: modelContext, streakStore: streakStore)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct ProjectBoardSection: View {
    var project: Project
    var modelContext: ModelContext
    var streakStore: StreakStore

    private var mainBoardColumns: [ProjectKanbanColumn] {
        project.kanbanColumns.filter { $0.sprint == nil }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        KanbanBoardSection(columns: mainBoardColumns, project: project, modelContext: modelContext, streakStore: streakStore)
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
    @State private var showArchivedSprints = false
    @State private var sprintPendingDeletion: ProjectSprint?

    private var visibleSprints: [ProjectSprint] {
        project.sprints
            .filter { showArchivedSprints || !$0.isArchived }
            .sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        Group {
            if let sprint = selected {
                SprintEditorView(sprint: sprint, modelContext: modelContext, streakStore: streakStore)
            } else if visibleSprints.isEmpty {
                ContentUnavailableView(
                    project.sprints.isEmpty ? "No sprints yet" : "No active sprints",
                    systemImage: "calendar.badge.clock",
                    description: Text(
                        project.sprints.isEmpty
                            ? "Add a sprint to plan a time box and its own board."
                            : "Turn on “Show archived sprints” to see archived ones."
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $selected) {
                    ForEach(visibleSprints) { sprint in
                        Button {
                            selected = sprint
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(sprint.title)
                                        .font(.headline)
                                    if sprint.isArchived {
                                        Text("Archived")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.quaternary, in: Capsule())
                                    }
                                }
                                Text("\(sprint.startDate.formatted(date: .abbreviated, time: .omitted)) – \(sprint.endDate.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .tag(sprint)
                        .contextMenu {
                            if sprint.isArchived {
                                Button("Unarchive sprint") {
                                    setSprintArchived(sprint, archived: false)
                                }
                            } else {
                                Button("Archive sprint") {
                                    setSprintArchived(sprint, archived: true)
                                }
                            }
                            Divider()
                            Button("Delete sprint…", role: .destructive) {
                                sprintPendingDeletion = sprint
                            }
                        }
                    }
                    .onDelete(perform: deleteSprintsAtOffsets)
                }
                .listStyle(.inset)
            }
        }
        .confirmationDialog(
            "Delete this sprint?",
            isPresented: Binding(
                get: { sprintPendingDeletion != nil },
                set: { if !$0 { sprintPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete sprint and its board", role: .destructive) {
                if let sprint = sprintPendingDeletion {
                    deleteSprintPermanently(sprint)
                }
                sprintPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                sprintPendingDeletion = nil
            }
        } message: {
            if let sprint = sprintPendingDeletion {
                Text("“\(sprint.title)” and its sprint board columns will be removed. Retrospectives that reference this sprint will keep their notes but lose the sprint link.")
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
                        ProjectBoardDefaults.ensureDefaultColumns(for: sprint, modelContext: modelContext)
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
                ToolbarItem(placement: .automatic) {
                    Button {
                        showArchivedSprints.toggle()
                    } label: {
                        Label(
                            showArchivedSprints ? "Hide archived sprints" : "Show archived sprints",
                            systemImage: showArchivedSprints ? "archivebox.fill" : "archivebox"
                        )
                    }
                }
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
                ToolbarItem(placement: .automatic) {
                    if let sprint = selected {
                        Menu {
                            if sprint.isArchived {
                                Button("Unarchive sprint") {
                                    setSprintArchived(sprint, archived: false)
                                }
                            } else {
                                Button("Archive sprint") {
                                    setSprintArchived(sprint, archived: true)
                                }
                            }
                            Divider()
                            Button("Delete sprint…", role: .destructive) {
                                sprintPendingDeletion = sprint
                            }
                        } label: {
                            Label("Sprint options", systemImage: "ellipsis.circle")
                        }
                    }
                }
            }
        }
    }

    private func setSprintArchived(_ sprint: ProjectSprint, archived: Bool) {
        sprint.isArchived = archived
        sprint.archivedAt = archived ? Date() : nil
        if archived, selected?.persistentModelID == sprint.persistentModelID, !showArchivedSprints {
            selected = nil
        }
        try? modelContext.save()
        streakStore.recordUsage()
    }

    private func deleteSprintPermanently(_ sprint: ProjectSprint) {
        if selected?.persistentModelID == sprint.persistentModelID {
            selected = nil
        }
        modelContext.delete(sprint)
        try? modelContext.save()
        streakStore.recordUsage()
    }

    private func deleteSprintsAtOffsets(_ offsets: IndexSet) {
        if offsets.count == 1, let index = offsets.first {
            sprintPendingDeletion = visibleSprints[index]
            return
        }
        for index in offsets {
            let s = visibleSprints[index]
            if selected?.persistentModelID == s.persistentModelID {
                selected = nil
            }
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
                        .contextMenu {
                            Button("Delete retrospective", role: .destructive) {
                                if selected?.persistentModelID == retro.persistentModelID {
                                    selected = nil
                                }
                                modelContext.delete(retro)
                                try? modelContext.save()
                                streakStore.recordUsage()
                            }
                        }
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
            if selected?.persistentModelID == r.persistentModelID { selected = nil }
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
                        .contextMenu {
                            Button("Delete event", role: .destructive) {
                                if selected?.persistentModelID == event.persistentModelID {
                                    selected = nil
                                }
                                modelContext.delete(event)
                                try? modelContext.save()
                                streakStore.recordUsage()
                            }
                        }
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
                ToolbarItem(placement: .primaryAction) {
                    Button("Delete event", role: .destructive) {
                        if let event = selected {
                            modelContext.delete(event)
                            try? modelContext.save()
                            selected = nil
                            streakStore.recordUsage()
                        }
                    }
                }
            }
        }
    }

    private func deleteEvents(at offsets: IndexSet) {
        for index in offsets {
            let e = sortedEvents[index]
            if selected?.persistentModelID == e.persistentModelID { selected = nil }
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
                    Button("Delete document", role: .destructive) {
                        modelContext.delete(doc)
                        try? modelContext.save()
                        streakStore.recordUsage()
                    }
                }
            }
            .onDelete(perform: deleteDocuments)
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

    private func deleteDocuments(at offsets: IndexSet) {
        let sortedDocs = project.documents.sorted { $0.addedAt > $1.addedAt }
        for index in offsets {
            modelContext.delete(sortedDocs[index])
        }
        try? modelContext.save()
        streakStore.recordUsage()
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

private enum SprintEditorTab: String, CaseIterable, Identifiable {
    case details = "Details"
    case board = "Board"
    var id: String { rawValue }
}

private struct SprintEditorView: View {
    @Bindable var sprint: ProjectSprint
    var modelContext: ModelContext
    var streakStore: StreakStore

    @State private var tab: SprintEditorTab = .details

    private var sprintBoardColumns: [ProjectKanbanColumn] {
        sprint.kanbanColumns.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Sprint section", selection: $tab) {
                ForEach(SprintEditorTab.allCases) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Group {
                switch tab {
                case .details:
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if sprint.isArchived {
                                HStack(alignment: .center, spacing: 12) {
                                    Label("This sprint is archived", systemImage: "archivebox.fill")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Spacer(minLength: 0)
                                    Button("Unarchive") {
                                        sprint.isArchived = false
                                        sprint.archivedAt = nil
                                        try? modelContext.save()
                                        streakStore.recordUsage()
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
                            }
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
                case .board:
                    KanbanBoardSection(columns: sprintBoardColumns, project: sprint.project, modelContext: modelContext, streakStore: streakStore)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            ProjectBoardDefaults.ensureDefaultColumns(for: sprint, modelContext: modelContext)
            try? modelContext.save()
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
