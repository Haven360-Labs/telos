import SwiftUI
import SwiftData

// MARK: - Kanban card editor (shared by board inspector & task list)

/// Single editor for a `ProjectKanbanCard` — same fields as the board and Tasks tab.
struct KanbanCardDetailForm: View {
    @Bindable var card: ProjectKanbanCard
    var project: Project?
    /// When set (e.g. main or sprint board), user can move the card between these columns.
    var columnsForMove: [ProjectKanbanColumn]?
    var modelContext: ModelContext
    var streakStore: StreakStore

    @Environment(DayStore.self) private var dayStore
    @Environment(TimerStore.self) private var timerStore
    @State private var newChecklistTitle = ""

    private var sortedMilestones: [ProjectMilestone] {
        (project?.milestones ?? []).sorted { $0.targetDate < $1.targetDate }
    }

    private var sortedColumns: [ProjectKanbanColumn] {
        (columnsForMove ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    private var sortedChecklist: [ProjectKanbanChecklistItem] {
        card.checklistItems.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        Form {
            Section("Card") {
                TextField("Title", text: $card.title)
                TextEditor(text: $card.body)
                    .frame(minHeight: 72)
                    .padding(6)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            }
            if !sortedColumns.isEmpty {
                Section("Column") {
                    Picker(
                        "Column",
                        selection: Binding(
                            get: { card.column },
                            set: { newCol in
                                guard let newCol else { return }
                                guard newCol.persistentModelID != card.column?.persistentModelID else { return }
                                KanbanBoardDragSupport.drop(
                                    dragged: card,
                                    targetColumn: newCol,
                                    before: nil,
                                    modelContext: modelContext,
                                    timerStore: timerStore
                                )
                                streakStore.recordUsage()
                            }
                        )
                    ) {
                        ForEach(sortedColumns) { col in
                            Text(col.title).tag(Optional(col))
                        }
                    }
                }
            }
            if project != nil {
                Section("Milestone") {
                    Picker("Link to milestone", selection: $card.milestone) {
                        Text("None").tag(nil as ProjectMilestone?)
                        ForEach(sortedMilestones) { m in
                            Text(m.title.isEmpty ? "Milestone" : m.title).tag(m as ProjectMilestone?)
                        }
                    }
                }
            }
            Section("Today") {
                if PlanTaskProjectLinking.isKanbanCardOnToday(card, dayStore: dayStore, modelContext: modelContext) {
                    Label("On Today's list", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.secondary)
                } else {
                    Button {
                        PlanTaskProjectLinking.ensureTodayPlanTask(
                            for: card,
                            dayStore: dayStore,
                            modelContext: modelContext,
                            streakStore: streakStore
                        )
                    } label: {
                        Label("Add to Today", systemImage: "sun.max")
                    }
                }
            }
            Section("Checklist") {
                ForEach(sortedChecklist) { item in
                    @Bindable var item = item
                    HStack {
                        Toggle(item.title, isOn: $item.isDone)
                        Spacer()
                        Button(role: .destructive) {
                            modelContext.delete(item)
                            try? modelContext.save()
                            streakStore.recordUsage()
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }
                }
                HStack {
                    TextField("New item", text: $newChecklistTitle)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        let t = newChecklistTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !t.isEmpty else { return }
                        let next = (card.checklistItems.map(\.sortOrder).max() ?? -1) + 1
                        let item = ProjectKanbanChecklistItem(title: t, sortOrder: next, card: card)
                        modelContext.insert(item)
                        card.checklistItems.append(item)
                        try? modelContext.save()
                        streakStore.recordUsage()
                        newChecklistTitle = ""
                    }
                    .disabled(newChecklistTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct KanbanCardInspectorSheet: View {
    @Bindable var card: ProjectKanbanCard
    var project: Project?
    var columnsForMove: [ProjectKanbanColumn]?
    var modelContext: ModelContext
    var streakStore: StreakStore
    var onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            KanbanCardDetailForm(
                card: card,
                project: project,
                columnsForMove: columnsForMove,
                modelContext: modelContext,
                streakStore: streakStore
            )
            .navigationTitle("Card")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        try? modelContext.save()
                        onDismiss()
                    }
                }
            }
        }
        .frame(minWidth: 420, minHeight: 520)
    }
}

// MARK: - Roadmap

struct ProjectRoadmapHubSection: View {
    @Bindable var project: Project
    var modelContext: ModelContext
    var streakStore: StreakStore

    @State private var selected: ProjectRoadmapItem?
    @State private var showAdd = false
    @State private var addTitle = ""
    @State private var addStart = Date()
    @State private var addEnd: Date?
    @State private var addHasEnd = false
    @State private var addNotes = ""

    private var sortedItems: [ProjectRoadmapItem] {
        project.roadmapItems.sorted { $0.targetStart < $1.targetStart }
    }

    var body: some View {
        Group {
            if let item = selected {
                roadmapDetail(item)
            } else {
                List(selection: $selected) {
                    ForEach(sortedItems) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.title).font(.headline)
                            Text(row.targetStart.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(row)
                    }
                    .onDelete(perform: deleteAt)
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $showAdd) {
            addSheet
        }
        .toolbar {
            if selected == nil {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add item") { showAdd = true }
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
                        if let item = selected {
                            modelContext.delete(item)
                            selected = nil
                            try? modelContext.save()
                            streakStore.recordUsage()
                        }
                    }
                }
            }
        }
    }

    private var addSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Roadmap item").font(.headline)
            TextField("Title", text: $addTitle).textFieldStyle(.roundedBorder)
            DatePicker("Target start", selection: $addStart, displayedComponents: .date)
            Toggle("End date", isOn: $addHasEnd)
            if addHasEnd {
                DatePicker("Target end", selection: Binding(get: { addEnd ?? addStart }, set: { addEnd = $0 }), displayedComponents: .date)
            }
            TextField("Notes", text: $addNotes, axis: .vertical).lineLimit(2...5).textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel") { showAdd = false }
                Button("Add") {
                    let t = addTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !t.isEmpty else { return }
                    let next = (project.roadmapItems.map(\.sortOrder).max() ?? -1) + 1
                    let end = addHasEnd ? addEnd.map { Calendar.current.startOfDay(for: $0) } : nil
                    let start = Calendar.current.startOfDay(for: addStart)
                    let item = ProjectRoadmapItem(
                        title: t,
                        targetStart: start,
                        targetEnd: end,
                        notes: addNotes,
                        sortOrder: next,
                        project: project,
                        epic: nil
                    )
                    modelContext.insert(item)
                    project.roadmapItems.append(item)
                    try? modelContext.save()
                    streakStore.recordUsage()
                    showAdd = false
                    addTitle = ""
                    addNotes = ""
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 360)
    }

    private func roadmapDetail(_ item: ProjectRoadmapItem) -> some View {
        @Bindable var item = item
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                TextField("Title", text: $item.title)
                    .font(.title2)
                    .textFieldStyle(.roundedBorder)
                DatePicker("Target start", selection: $item.targetStart, displayedComponents: .date)
                Toggle("Has end date", isOn: Binding(
                    get: { item.targetEnd != nil },
                    set: { on in
                        if !on { item.targetEnd = nil }
                        else if item.targetEnd == nil { item.targetEnd = item.targetStart }
                    }
                ))
                if item.targetEnd != nil {
                    DatePicker(
                        "Target end",
                        selection: Binding(get: { item.targetEnd ?? item.targetStart }, set: { item.targetEnd = $0 }),
                        displayedComponents: .date
                    )
                }
                TextEditor(text: $item.notes)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))

                if !item.milestones.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Milestones")
                            .font(.headline)
                        ForEach(item.milestones.sorted { $0.targetDate < $1.targetDate }) { ms in
                            HStack {
                                Text(ms.title)
                                Spacer()
                                Text(ms.targetDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .padding(24)
        }
        .onDisappear { try? modelContext.save() }
    }

    private func deleteAt(_ offsets: IndexSet) {
        for index in offsets {
            let item = sortedItems[index]
            if selected?.persistentModelID == item.persistentModelID { selected = nil }
            modelContext.delete(item)
        }
        try? modelContext.save()
        streakStore.recordUsage()
    }
}

// MARK: - Milestones

struct ProjectMilestonesHubSection: View {
    @Bindable var project: Project
    var modelContext: ModelContext
    var streakStore: StreakStore

    @State private var selected: ProjectMilestone?
    @State private var showAdd = false
    @State private var addTitle = ""
    @State private var addDate = Date()
    @State private var addRoadmap: ProjectRoadmapItem?

    private var sortedMilestones: [ProjectMilestone] {
        project.milestones.sorted { $0.targetDate < $1.targetDate }
    }

    private var sortedRoadmapItems: [ProjectRoadmapItem] {
        project.roadmapItems.sorted { $0.targetStart < $1.targetStart }
    }

    var body: some View {
        Group {
            if let m = selected {
                milestoneDetail(m)
            } else {
                List(selection: $selected) {
                    ForEach(sortedMilestones) { row in
                        @Bindable var row = row
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(row.title).font(.headline)
                                Text(row.targetDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let rm = row.roadmapItem {
                                    Text(rm.title)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            Spacer()
                            Toggle("", isOn: $row.isCompleted)
                                .labelsHidden()
                        }
                        .tag(row)
                    }
                    .onDelete(perform: deleteAt)
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $showAdd) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Milestone").font(.headline)
                TextField("Title", text: $addTitle).textFieldStyle(.roundedBorder)
                DatePicker("Target date", selection: $addDate, displayedComponents: .date)
                Picker("Roadmap item", selection: $addRoadmap) {
                    Text("None").tag(nil as ProjectRoadmapItem?)
                    ForEach(sortedRoadmapItems) { rm in
                        Text(rm.title).tag(rm as ProjectRoadmapItem?)
                    }
                }
                HStack {
                    Spacer()
                    Button("Cancel") { showAdd = false }
                    Button("Add") {
                        let t = addTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !t.isEmpty else { return }
                        let next = (project.milestones.map(\.sortOrder).max() ?? -1) + 1
                        let m = ProjectMilestone(
                            title: t,
                            targetDate: Calendar.current.startOfDay(for: addDate),
                            sortOrder: next,
                            project: project,
                            epic: nil,
                            roadmapItem: addRoadmap
                        )
                        modelContext.insert(m)
                        project.milestones.append(m)
                        try? modelContext.save()
                        streakStore.recordUsage()
                        showAdd = false
                        addTitle = ""
                        addRoadmap = nil
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(minWidth: 340)
        }
        .toolbar {
            if selected == nil {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add milestone") {
                        addRoadmap = nil
                        showAdd = true
                    }
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
                        if let m = selected {
                            modelContext.delete(m)
                            selected = nil
                            try? modelContext.save()
                            streakStore.recordUsage()
                        }
                    }
                }
            }
        }
    }

    private func milestoneDetail(_ m: ProjectMilestone) -> some View {
        @Bindable var m = m
        return Form {
            TextField("Title", text: $m.title)
            DatePicker("Target date", selection: $m.targetDate, displayedComponents: .date)
            Toggle("Completed", isOn: $m.isCompleted)
            Picker("Roadmap item", selection: $m.roadmapItem) {
                Text("None").tag(nil as ProjectRoadmapItem?)
                ForEach(sortedRoadmapItems) { rm in
                    Text(rm.title).tag(rm as ProjectRoadmapItem?)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onDisappear { try? modelContext.save() }
    }

    private func deleteAt(_ offsets: IndexSet) {
        for index in offsets {
            let m = sortedMilestones[index]
            if selected?.persistentModelID == m.persistentModelID { selected = nil }
            modelContext.delete(m)
        }
        try? modelContext.save()
        streakStore.recordUsage()
    }
}

// MARK: - Releases + checklist

struct ProjectReleasesHubSection: View {
    @Bindable var project: Project
    var modelContext: ModelContext
    var streakStore: StreakStore

    @State private var selected: ProjectRelease?
    @State private var showAdd = false
    @State private var addVersion = ""
    @State private var addTarget: Date?
    @State private var addHasTarget = false
    @State private var newChecklistTitle = ""

    private var sortedReleases: [ProjectRelease] {
        project.releases.sorted { ($0.targetDate ?? .distantFuture) < ($1.targetDate ?? .distantFuture) }
    }

    var body: some View {
        Group {
            if let rel = selected {
                releaseDetail(rel)
            } else {
                List(selection: $selected) {
                    ForEach(sortedReleases) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.version).font(.headline)
                            Text(row.status).font(.caption).foregroundStyle(.secondary)
                        }
                        .tag(row)
                    }
                    .onDelete(perform: deleteAt)
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $showAdd) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Release").font(.headline)
                TextField("Version (e.g. 1.2.0)", text: $addVersion).textFieldStyle(.roundedBorder)
                Toggle("Target date", isOn: $addHasTarget)
                if addHasTarget {
                    DatePicker("", selection: Binding(get: { addTarget ?? Date() }, set: { addTarget = $0 }), displayedComponents: .date)
                }
                HStack {
                    Spacer()
                    Button("Cancel") { showAdd = false }
                    Button("Add") {
                        let v = addVersion.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !v.isEmpty else { return }
                        let rel = ProjectRelease(
                            version: v,
                            targetDate: addHasTarget ? Calendar.current.startOfDay(for: addTarget ?? Date()) : nil,
                            project: project
                        )
                        modelContext.insert(rel)
                        project.releases.append(rel)
                        try? modelContext.save()
                        streakStore.recordUsage()
                        showAdd = false
                        addVersion = ""
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(minWidth: 320)
        }
        .toolbar {
            if selected == nil {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add release") { showAdd = true }
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
                        if let rel = selected {
                            modelContext.delete(rel)
                            selected = nil
                            try? modelContext.save()
                            streakStore.recordUsage()
                        }
                    }
                }
            }
        }
    }

    private func releaseDetail(_ rel: ProjectRelease) -> some View {
        @Bindable var rel = rel
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                TextField("Version", text: $rel.version)
                    .font(.title2)
                    .textFieldStyle(.roundedBorder)
                TextField("Status", text: $rel.status)
                    .textFieldStyle(.roundedBorder)
                DatePicker(
                    "Target date",
                    selection: Binding(
                        get: { rel.targetDate ?? Date() },
                        set: { rel.targetDate = $0 }
                    ),
                    displayedComponents: .date
                )
                Text("Checklist").font(.headline)
                ForEach(rel.checklistItems.sorted { $0.sortOrder < $1.sortOrder }) { item in
                    @Bindable var item = item
                    HStack {
                        Toggle(item.title, isOn: $item.isDone)
                        Spacer()
                        Button(role: .destructive) {
                            modelContext.delete(item)
                            try? modelContext.save()
                            streakStore.recordUsage()
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.plain)
                    }
                }
                HStack {
                    TextField("Checklist item", text: $newChecklistTitle)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        let t = newChecklistTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !t.isEmpty else { return }
                        let next = (rel.checklistItems.map(\.sortOrder).max() ?? -1) + 1
                        let item = ReleaseChecklistItem(title: t, sortOrder: next, release: rel)
                        modelContext.insert(item)
                        rel.checklistItems.append(item)
                        try? modelContext.save()
                        streakStore.recordUsage()
                        newChecklistTitle = ""
                    }
                }
            }
            .padding(24)
        }
        .onDisappear { try? modelContext.save() }
    }

    private func deleteAt(_ offsets: IndexSet) {
        for index in offsets {
            let r = sortedReleases[index]
            if selected?.persistentModelID == r.persistentModelID { selected = nil }
            modelContext.delete(r)
        }
        try? modelContext.save()
        streakStore.recordUsage()
    }
}

// MARK: - Tasks (board cards — same data as Board tab)

/// Lists and edits **`ProjectKanbanCard`** for the main board (`sprint == nil`) or a chosen sprint board.
struct ProjectBoardTaskListSection: View {
    @Bindable var project: Project
    /// When set, list/edit cards on this sprint’s board; when `nil`, the project main board.
    var sprint: ProjectSprint?
    var modelContext: ModelContext
    var streakStore: StreakStore

    @Environment(DayStore.self) private var dayStore
    @State private var selected: ProjectKanbanCard?
    @State private var filterColumn: ProjectKanbanColumn?
    @State private var showAdd = false

    private var boardColumns: [ProjectKanbanColumn] {
        if let sprint {
            return sprint.kanbanColumns.sorted { $0.sortOrder < $1.sortOrder }
        }
        return project.kanbanColumns.filter { $0.sprint == nil }.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var sortedMilestones: [ProjectMilestone] {
        project.milestones.sorted { $0.targetDate < $1.targetDate }
    }

    private var visibleCards: [ProjectKanbanCard] {
        boardColumns.flatMap { col in
            col.sortedCards.filter { card in
                filterColumn == nil || card.column?.persistentModelID == filterColumn?.persistentModelID
            }
        }
    }

    var body: some View {
        Group {
            if let card = selected {
                KanbanCardDetailForm(
                    card: card,
                    project: project,
                    columnsForMove: boardColumns,
                    modelContext: modelContext,
                    streakStore: streakStore
                )
                .padding()
                .onDisappear { try? modelContext.save() }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Picker("Column filter", selection: $filterColumn) {
                        Text("All columns").tag(nil as ProjectKanbanColumn?)
                        ForEach(boardColumns) { col in
                            Text(col.title).tag(col as ProjectKanbanColumn?)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    List(selection: $selected) {
                        ForEach(visibleCards) { row in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(row.title.isEmpty ? "Untitled" : row.title)
                                        .font(.headline)
                                    if PlanTaskProjectLinking.isKanbanCardOnToday(row, dayStore: dayStore, modelContext: modelContext) {
                                        Image(systemName: "sun.max.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                            .help("On Today's list")
                                    }
                                }
                                if let col = row.column {
                                    Text(col.title)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let ms = row.milestone {
                                    Text(ms.title)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .tag(row)
                            .contextMenu {
                                if PlanTaskProjectLinking.isKanbanCardOnToday(row, dayStore: dayStore, modelContext: modelContext) {
                                    Button {} label: {
                                        Label("On Today's list", systemImage: "checkmark")
                                    }
                                    .disabled(true)
                                } else {
                                    Button {
                                        PlanTaskProjectLinking.ensureTodayPlanTask(
                                            for: row,
                                            dayStore: dayStore,
                                            modelContext: modelContext,
                                            streakStore: streakStore
                                        )
                                    } label: {
                                        Label("Add to Today", systemImage: "sun.max")
                                    }
                                }
                            }
                        }
                        .onDelete(perform: deleteAt)
                    }
                    .listStyle(.inset)
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            WorkBoardNewCardSheet(
                columns: boardColumns,
                sortedMilestones: sortedMilestones,
                modelContext: modelContext,
                streakStore: streakStore,
                onDismiss: { showAdd = false }
            )
        }
        .onAppear {
            if let sprint {
                ProjectBoardDefaults.ensureDefaultColumns(for: sprint, modelContext: modelContext)
                try? modelContext.save()
            }
        }
        .toolbar {
            if selected == nil {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add task") { showAdd = true }
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
                        if let c = selected {
                            modelContext.delete(c)
                            selected = nil
                            try? modelContext.save()
                            streakStore.recordUsage()
                        }
                    }
                }
            }
        }
    }

    private func deleteAt(_ offsets: IndexSet) {
        for index in offsets {
            let c = visibleCards[index]
            if selected?.persistentModelID == c.persistentModelID { selected = nil }
            modelContext.delete(c)
        }
        try? modelContext.save()
        streakStore.recordUsage()
    }
}

private struct WorkBoardNewCardSheet: View {
    var columns: [ProjectKanbanColumn]
    var sortedMilestones: [ProjectMilestone]
    var modelContext: ModelContext
    var streakStore: StreakStore
    var onDismiss: () -> Void

    @State private var title = ""
    @State private var bodyText = ""
    @State private var column: ProjectKanbanColumn?
    @State private var milestone: ProjectMilestone?

    private var sortedColumns: [ProjectKanbanColumn] {
        columns.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New task").font(.headline)
            TextField("Title", text: $title).textFieldStyle(.roundedBorder)
            TextEditor(text: $bodyText)
                .frame(height: 100)
                .padding(8)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            Picker("Column", selection: $column) {
                ForEach(sortedColumns) { col in
                    Text(col.title).tag(Optional(col))
                }
            }
            Picker("Milestone", selection: $milestone) {
                Text("None").tag(nil as ProjectMilestone?)
                ForEach(sortedMilestones) { m in
                    Text(m.title.isEmpty ? "Milestone" : m.title).tag(m as ProjectMilestone?)
                }
            }
            HStack {
                Spacer()
                Button("Cancel", action: onDismiss)
                Button("Add") {
                    let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !t.isEmpty, let col = column ?? sortedColumns.first else { return }
                    let nextOrder = (col.cards.map(\.sortOrder).max() ?? -1) + 1
                    let card = ProjectKanbanCard(title: t, body: bodyText, sortOrder: nextOrder, column: col, milestone: milestone)
                    modelContext.insert(card)
                    col.cards.append(card)
                    try? modelContext.save()
                    streakStore.recordUsage()
                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || columns.isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 400)
        .onAppear {
            if column == nil {
                column = sortedColumns.first
            }
        }
    }
}

// MARK: - Testing

struct ProjectTestingHubSection: View {
    @Bindable var project: Project
    var modelContext: ModelContext
    var streakStore: StreakStore

    @State private var selectedSuite: ProjectTestSuite?
    @State private var showAddSuite = false
    @State private var newSuiteName = ""
    @State private var newCaseTitle = ""

    private var sortedSuites: [ProjectTestSuite] {
        project.testSuites.sorted { $0.name < $1.name }
    }

    var body: some View {
        Group {
            if let suite = selectedSuite {
                suiteDetail(suite)
            } else {
                List(selection: $selectedSuite) {
                    ForEach(sortedSuites) { s in
                        Text(s.name).tag(s)
                    }
                    .onDelete(perform: deleteSuiteAt)
                }
                .listStyle(.inset)
            }
        }
        .sheet(isPresented: $showAddSuite) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Test suite").font(.headline)
                TextField("Name", text: $newSuiteName).textFieldStyle(.roundedBorder)
                HStack {
                    Spacer()
                    Button("Cancel") { showAddSuite = false }
                    Button("Add") {
                        let n = newSuiteName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !n.isEmpty else { return }
                        let s = ProjectTestSuite(name: n, project: project)
                        modelContext.insert(s)
                        project.testSuites.append(s)
                        try? modelContext.save()
                        streakStore.recordUsage()
                        showAddSuite = false
                        newSuiteName = ""
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(minWidth: 280)
        }
        .toolbar {
            if selectedSuite == nil {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add suite") { showAddSuite = true }
                }
            } else {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        try? modelContext.save()
                        selectedSuite = nil
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Delete suite", role: .destructive) {
                        if let s = selectedSuite {
                            modelContext.delete(s)
                            selectedSuite = nil
                            try? modelContext.save()
                            streakStore.recordUsage()
                        }
                    }
                }
            }
        }
    }

    private func suiteDetail(_ suite: ProjectTestSuite) -> some View {
        @Bindable var suite = suite
        return List {
            Section {
                ForEach(suite.cases.sorted { $0.sortOrder < $1.sortOrder }) { tc in
                    @Bindable var tc = tc
                    VStack(alignment: .leading, spacing: 6) {
                        TextField("Title", text: $tc.title)
                        TextField("Status", text: $tc.status)
                        TextEditor(text: $tc.steps)
                            .frame(minHeight: 60)
                    }
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            modelContext.delete(tc)
                            try? modelContext.save()
                            streakStore.recordUsage()
                        }
                    }
                }
                .onDelete { idx in
                    let sorted = suite.cases.sorted { $0.sortOrder < $1.sortOrder }
                    for i in idx {
                        modelContext.delete(sorted[i])
                    }
                    try? modelContext.save()
                    streakStore.recordUsage()
                }
            } header: {
                HStack {
                    Text("Cases")
                    Spacer()
                    Button("Add case") {
                        let t = newCaseTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        let title = t.isEmpty ? "New case" : t
                        let next = (suite.cases.map(\.sortOrder).max() ?? -1) + 1
                        let tc = ProjectTestCase(title: title, sortOrder: next, suite: suite)
                        modelContext.insert(tc)
                        suite.cases.append(tc)
                        try? modelContext.save()
                        streakStore.recordUsage()
                        newCaseTitle = ""
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    private func deleteSuiteAt(_ offsets: IndexSet) {
        for index in offsets {
            let s = sortedSuites[index]
            if selectedSuite?.persistentModelID == s.persistentModelID { selectedSuite = nil }
            modelContext.delete(s)
        }
        try? modelContext.save()
        streakStore.recordUsage()
    }
}
