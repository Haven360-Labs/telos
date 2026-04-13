import SwiftUI
import SwiftData

// MARK: - Kanban card inspector (epic, RICE, WSJF, checklist)

struct KanbanCardInspectorSheet: View {
    @Bindable var card: ProjectKanbanCard
    var project: Project?
    var modelContext: ModelContext
    var streakStore: StreakStore
    var onDismiss: () -> Void

    @State private var newChecklistTitle = ""

    private var sortedEpics: [ProjectEpic] {
        (project?.epics ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    private var sortedChecklist: [ProjectKanbanChecklistItem] {
        card.checklistItems.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        NavigationStack {
            Form {
                if project != nil {
                    Section("Epic") {
                        Picker("Epic", selection: $card.epic) {
                            Text("None").tag(nil as ProjectEpic?)
                            ForEach(sortedEpics) { epic in
                                Text(epic.title).tag(epic as ProjectEpic?)
                            }
                        }
                    }
                }
                Section("RICE (1–10, 0 = unset)") {
                    Stepper("Reach: \(card.riceReach)", value: $card.riceReach, in: 0...10)
                    Stepper("Impact: \(card.riceImpact)", value: $card.riceImpact, in: 0...10)
                    Stepper("Confidence: \(card.riceConfidence)", value: $card.riceConfidence, in: 0...10)
                    Stepper("Effort: \(card.riceEffort)", value: $card.riceEffort, in: 0...10)
                    if let r = KanbanCardScoring.riceScore(card: card) {
                        Text("RICE score: \(r, format: .number.precision(.fractionLength(2)))")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Set all values with Effort > 0 to see score")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                Section("WSJF (0 = unset)") {
                    TextField("Cost of delay", value: $card.wsjfCostOfDelay, format: .number)
                        .textFieldStyle(.roundedBorder)
                    TextField("Job size", value: $card.wsjfJobSize, format: .number)
                        .textFieldStyle(.roundedBorder)
                    if let w = KanbanCardScoring.wsjfScore(card: card) {
                        Text("WSJF score: \(w, format: .number.precision(.fractionLength(3)))")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Set cost of delay and job size > 0")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
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
            .navigationTitle("Card details")
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

// MARK: - Epics & themes

struct ProjectEpicsHubSection: View {
    @Bindable var project: Project
    var modelContext: ModelContext
    var streakStore: StreakStore

    @State private var newThemeName = ""
    @State private var newEpicTitle = ""
    @State private var epicThemePick: ProjectTheme?

    private var sortedThemes: [ProjectTheme] {
        project.themes.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var orphanEpics: [ProjectEpic] {
        project.epics.filter { $0.theme == nil }.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox("New theme") {
                    HStack {
                        TextField("Theme name", text: $newThemeName)
                            .textFieldStyle(.roundedBorder)
                        Button("Add") {
                            let t = newThemeName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !t.isEmpty else { return }
                            let order = (project.themes.map(\.sortOrder).max() ?? -1) + 1
                            let theme = ProjectTheme(title: t, sortOrder: order, project: project)
                            modelContext.insert(theme)
                            project.themes.append(theme)
                            try? modelContext.save()
                            streakStore.recordUsage()
                            newThemeName = ""
                        }
                        .disabled(newThemeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                GroupBox("New epic") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Epic title", text: $newEpicTitle)
                            .textFieldStyle(.roundedBorder)
                        Picker("Theme", selection: $epicThemePick) {
                            Text("None").tag(nil as ProjectTheme?)
                            ForEach(sortedThemes) { th in
                                Text(th.title).tag(th as ProjectTheme?)
                            }
                        }
                        Button("Add epic") {
                            let t = newEpicTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !t.isEmpty else { return }
                            let order = (project.epics.map(\.sortOrder).max() ?? -1) + 1
                            let epic = ProjectEpic(title: t, sortOrder: order, project: project, theme: epicThemePick)
                            modelContext.insert(epic)
                            project.epics.append(epic)
                            try? modelContext.save()
                            streakStore.recordUsage()
                            newEpicTitle = ""
                        }
                        .disabled(newEpicTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                ForEach(sortedThemes) { theme in
                    GroupBox(theme.title) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(theme.epics.sorted { $0.sortOrder < $1.sortOrder }) { epic in
                                epicRow(epic)
                            }
                            if theme.epics.isEmpty {
                                Text("No epics in this theme")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .contextMenu {
                        Button("Delete theme", role: .destructive) {
                            modelContext.delete(theme)
                            try? modelContext.save()
                            streakStore.recordUsage()
                        }
                    }
                }
                if !orphanEpics.isEmpty {
                    GroupBox("Epics without theme") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(orphanEpics) { epic in
                                epicRow(epic)
                            }
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private func epicRow(_ epic: ProjectEpic) -> some View {
        HStack {
            Text(epic.title)
            Spacer()
            Button(role: .destructive) {
                modelContext.delete(epic)
                try? modelContext.save()
                streakStore.recordUsage()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
        }
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
    @State private var addEpic: ProjectEpic?

    private var sortedItems: [ProjectRoadmapItem] {
        project.roadmapItems.sorted { $0.targetStart < $1.targetStart }
    }

    private var sortedEpics: [ProjectEpic] {
        project.epics.sorted { $0.sortOrder < $1.sortOrder }
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
            Picker("Epic", selection: $addEpic) {
                Text("None").tag(nil as ProjectEpic?)
                ForEach(sortedEpics) { e in
                    Text(e.title).tag(e as ProjectEpic?)
                }
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
                        epic: addEpic
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
                Picker("Epic", selection: $item.epic) {
                    Text("None").tag(nil as ProjectEpic?)
                    ForEach(sortedEpics) { e in
                        Text(e.title).tag(e as ProjectEpic?)
                    }
                }
                TextEditor(text: $item.notes)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
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

// MARK: - Decisions

struct ProjectDecisionsHubSection: View {
    @Bindable var project: Project
    var modelContext: ModelContext
    var streakStore: StreakStore

    @State private var selected: ProjectDecision?
    @State private var showAdd = false
    @State private var addTitle = ""
    @State private var addContext = ""
    @State private var addDecision = ""
    @State private var addRationale = ""

    private var sortedDecisions: [ProjectDecision] {
        project.decisions.sorted { $0.decidedAt > $1.decidedAt }
    }

    var body: some View {
        Group {
            if let d = selected {
                decisionDetail(d)
            } else {
                List(selection: $selected) {
                    ForEach(sortedDecisions) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.title).font(.headline)
                            Text(row.decidedAt.formatted(date: .abbreviated, time: .shortened))
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
            VStack(alignment: .leading, spacing: 12) {
                Text("Decision").font(.headline)
                TextField("Title", text: $addTitle).textFieldStyle(.roundedBorder)
                TextField("Context", text: $addContext, axis: .vertical).lineLimit(2...4).textFieldStyle(.roundedBorder)
                TextField("Decision", text: $addDecision, axis: .vertical).lineLimit(2...4).textFieldStyle(.roundedBorder)
                TextField("Rationale", text: $addRationale, axis: .vertical).lineLimit(2...6).textFieldStyle(.roundedBorder)
                HStack {
                    Spacer()
                    Button("Cancel") { showAdd = false }
                    Button("Save") {
                        let t = addTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !t.isEmpty else { return }
                        let dec = ProjectDecision(
                            title: t,
                            context: addContext,
                            decision: addDecision,
                            rationale: addRationale,
                            project: project
                        )
                        modelContext.insert(dec)
                        project.decisions.append(dec)
                        try? modelContext.save()
                        streakStore.recordUsage()
                        showAdd = false
                        addTitle = ""
                        addContext = ""
                        addDecision = ""
                        addRationale = ""
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(minWidth: 380)
        }
        .toolbar {
            if selected == nil {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add decision") { showAdd = true }
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
                        if let d = selected {
                            modelContext.delete(d)
                            selected = nil
                            try? modelContext.save()
                            streakStore.recordUsage()
                        }
                    }
                }
            }
        }
    }

    private func decisionDetail(_ d: ProjectDecision) -> some View {
        @Bindable var d = d
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Title", text: $d.title).font(.title2).textFieldStyle(.roundedBorder)
                DatePicker("Decided", selection: $d.decidedAt, displayedComponents: [.date, .hourAndMinute])
                labeledField("Context", text: $d.context)
                labeledField("Decision", text: $d.decision)
                labeledField("Rationale", text: $d.rationale)
            }
            .padding(24)
        }
        .onDisappear { try? modelContext.save() }
    }

    private func labeledField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextEditor(text: text)
                .frame(minHeight: 72)
                .padding(8)
                .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func deleteAt(_ offsets: IndexSet) {
        for index in offsets {
            let d = sortedDecisions[index]
            if selected?.persistentModelID == d.persistentModelID { selected = nil }
            modelContext.delete(d)
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
    @State private var addEpic: ProjectEpic?

    private var sortedMilestones: [ProjectMilestone] {
        project.milestones.sorted { $0.targetDate < $1.targetDate }
    }

    private var sortedEpics: [ProjectEpic] {
        project.epics.sorted { $0.sortOrder < $1.sortOrder }
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
                Picker("Epic", selection: $addEpic) {
                    Text("None").tag(nil as ProjectEpic?)
                    ForEach(sortedEpics) { e in
                        Text(e.title).tag(e as ProjectEpic?)
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
                            epic: addEpic
                        )
                        modelContext.insert(m)
                        project.milestones.append(m)
                        try? modelContext.save()
                        streakStore.recordUsage()
                        showAdd = false
                        addTitle = ""
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
                    Button("Add milestone") { showAdd = true }
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
            Picker("Epic", selection: $m.epic) {
                Text("None").tag(nil as ProjectEpic?)
                ForEach(sortedEpics) { e in
                    Text(e.title).tag(e as ProjectEpic?)
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
                Text("Link changelog entries from the Changelog section for this version.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

// MARK: - Changelog

struct ProjectChangelogHubSection: View {
    @Bindable var project: Project
    var modelContext: ModelContext
    var streakStore: StreakStore

    @State private var selected: ProjectChangelogEntry?
    @State private var showAdd = false
    @State private var addVersion = ""
    @State private var addDate = Date()
    @State private var addBody = ""
    @State private var addRelease: ProjectRelease?

    private var sortedEntries: [ProjectChangelogEntry] {
        project.changelogEntries.sorted { $0.date > $1.date }
    }

    private var sortedReleases: [ProjectRelease] {
        project.releases.sorted { $0.version < $1.version }
    }

    var body: some View {
        Group {
            if let entry = selected {
                changelogDetail(entry)
            } else {
                List(selection: $selected) {
                    ForEach(sortedEntries) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.version).font(.headline)
                            Text(row.date.formatted(date: .abbreviated, time: .omitted))
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
            VStack(alignment: .leading, spacing: 12) {
                Text("Changelog entry").font(.headline)
                TextField("Version", text: $addVersion).textFieldStyle(.roundedBorder)
                DatePicker("Date", selection: $addDate, displayedComponents: .date)
                Picker("Release (optional)", selection: $addRelease) {
                    Text("None").tag(nil as ProjectRelease?)
                    ForEach(sortedReleases) { r in
                        Text(r.version).tag(r as ProjectRelease?)
                    }
                }
                TextEditor(text: $addBody)
                    .frame(height: 140)
                    .padding(8)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                HStack {
                    Spacer()
                    Button("Cancel") { showAdd = false }
                    Button("Add") {
                        let v = addVersion.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !v.isEmpty, !addBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        let entry = ProjectChangelogEntry(
                            version: v,
                            date: Calendar.current.startOfDay(for: addDate),
                            body: addBody,
                            project: project,
                            release: addRelease
                        )
                        modelContext.insert(entry)
                        project.changelogEntries.append(entry)
                        try? modelContext.save()
                        streakStore.recordUsage()
                        showAdd = false
                        addVersion = ""
                        addBody = ""
                        addRelease = nil
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(minWidth: 400)
        }
        .toolbar {
            if selected == nil {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add entry") { showAdd = true }
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
                        if let e = selected {
                            modelContext.delete(e)
                            selected = nil
                            try? modelContext.save()
                            streakStore.recordUsage()
                        }
                    }
                }
            }
        }
    }

    private func changelogDetail(_ entry: ProjectChangelogEntry) -> some View {
        @Bindable var entry = entry
        return ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Version", text: $entry.version).font(.title2).textFieldStyle(.roundedBorder)
                DatePicker("Date", selection: $entry.date, displayedComponents: .date)
                Picker("Release", selection: $entry.release) {
                    Text("None").tag(nil as ProjectRelease?)
                    ForEach(sortedReleases) { r in
                        Text(r.version).tag(r as ProjectRelease?)
                    }
                }
                TextEditor(text: $entry.body)
                    .frame(minHeight: 200)
                    .padding(8)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            }
            .padding(24)
        }
        .onDisappear { try? modelContext.save() }
    }

    private func deleteAt(_ offsets: IndexSet) {
        for index in offsets {
            let e = sortedEntries[index]
            if selected?.persistentModelID == e.persistentModelID { selected = nil }
            modelContext.delete(e)
        }
        try? modelContext.save()
        streakStore.recordUsage()
    }
}

// MARK: - Issues

struct ProjectIssuesHubSection: View {
    @Bindable var project: Project
    var modelContext: ModelContext
    var streakStore: StreakStore

    @State private var selected: ProjectIssue?
    @State private var filterStatus = "all"
    @State private var showAdd = false

    private let statuses = ["all", "open", "in progress", "done", "closed"]

    private var sortedEpics: [ProjectEpic] {
        project.epics.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var sortedSprints: [ProjectSprint] {
        project.sprints.sorted { $0.startDate > $1.startDate }
    }

    private var allCards: [ProjectKanbanCard] {
        project.kanbanColumns.flatMap(\.cards)
    }

    private var visibleIssues: [ProjectIssue] {
        let list = project.issues.sorted { $0.createdAt > $1.createdAt }
        if filterStatus == "all" { return list }
        return list.filter { $0.status.lowercased() == filterStatus }
    }

    var body: some View {
        Group {
            if let issue = selected {
                issueDetail(issue)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Picker("Status", selection: $filterStatus) {
                        ForEach(statuses, id: \.self) { s in
                            Text(s.capitalized).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    List(selection: $selected) {
                        ForEach(visibleIssues) { row in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(row.title).font(.headline)
                                Text("\(row.kind) · \(row.status)")
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
        }
        .sheet(isPresented: $showAdd) {
            IssueAddSheet(
                project: project,
                modelContext: modelContext,
                streakStore: streakStore,
                sortedEpics: sortedEpics,
                sortedSprints: sortedSprints,
                allCards: allCards,
                onDismiss: { showAdd = false }
            )
        }
        .toolbar {
            if selected == nil {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add issue") { showAdd = true }
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
                        if let i = selected {
                            modelContext.delete(i)
                            selected = nil
                            try? modelContext.save()
                            streakStore.recordUsage()
                        }
                    }
                }
            }
        }
    }

    private func issueDetail(_ issue: ProjectIssue) -> some View {
        @Bindable var issue = issue
        return Form {
            TextField("Title", text: $issue.title)
            TextField("Kind", text: $issue.kind)
            TextField("Status", text: $issue.status)
            TextField("Priority", text: $issue.priority)
            Picker("Epic", selection: $issue.epic) {
                Text("None").tag(nil as ProjectEpic?)
                ForEach(sortedEpics) { e in
                    Text(e.title).tag(e as ProjectEpic?)
                }
            }
            Picker("Sprint", selection: $issue.sprint) {
                Text("None").tag(nil as ProjectSprint?)
                ForEach(sortedSprints) { s in
                    Text(s.title).tag(s as ProjectSprint?)
                }
            }
            Picker("Kanban card", selection: $issue.kanbanCard) {
                Text("None").tag(nil as ProjectKanbanCard?)
                ForEach(allCards) { c in
                    Text(c.title.isEmpty ? "Untitled card" : c.title).tag(c as ProjectKanbanCard?)
                }
            }
            TextEditor(text: $issue.detail)
                .frame(minHeight: 120)
        }
        .formStyle(.grouped)
        .padding()
        .onDisappear { try? modelContext.save() }
    }

    private func deleteAt(_ offsets: IndexSet) {
        for index in offsets {
            let i = visibleIssues[index]
            if selected?.persistentModelID == i.persistentModelID { selected = nil }
            modelContext.delete(i)
        }
        try? modelContext.save()
        streakStore.recordUsage()
    }
}

private struct IssueAddSheet: View {
    var project: Project
    var modelContext: ModelContext
    var streakStore: StreakStore
    var sortedEpics: [ProjectEpic]
    var sortedSprints: [ProjectSprint]
    var allCards: [ProjectKanbanCard]
    var onDismiss: () -> Void

    @State private var title = ""
    @State private var detail = ""
    @State private var kind = "task"
    @State private var status = "open"
    @State private var priority = "medium"
    @State private var epic: ProjectEpic?
    @State private var sprint: ProjectSprint?
    @State private var card: ProjectKanbanCard?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New issue").font(.headline)
            TextField("Title", text: $title).textFieldStyle(.roundedBorder)
            TextField("Kind", text: $kind).textFieldStyle(.roundedBorder)
            TextField("Status", text: $status).textFieldStyle(.roundedBorder)
            TextField("Priority", text: $priority).textFieldStyle(.roundedBorder)
            Picker("Epic", selection: $epic) {
                Text("None").tag(nil as ProjectEpic?)
                ForEach(sortedEpics) { e in
                    Text(e.title).tag(e as ProjectEpic?)
                }
            }
            Picker("Sprint", selection: $sprint) {
                Text("None").tag(nil as ProjectSprint?)
                ForEach(sortedSprints) { s in
                    Text(s.title).tag(s as ProjectSprint?)
                }
            }
            Picker("Card", selection: $card) {
                Text("None").tag(nil as ProjectKanbanCard?)
                ForEach(allCards) { c in
                    Text(c.title.isEmpty ? "Untitled" : c.title).tag(c as ProjectKanbanCard?)
                }
            }
            TextEditor(text: $detail).frame(height: 100).padding(8).background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            HStack {
                Spacer()
                Button("Cancel", action: onDismiss)
                Button("Add") {
                    let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !t.isEmpty else { return }
                    let issue = ProjectIssue(
                        title: t,
                        detail: detail,
                        kind: kind,
                        status: status,
                        priority: priority,
                        project: project,
                        epic: epic,
                        sprint: sprint,
                        kanbanCard: card
                    )
                    modelContext.insert(issue)
                    project.issues.append(issue)
                    try? modelContext.save()
                    streakStore.recordUsage()
                    onDismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 400)
    }
}

// MARK: - Risks

struct ProjectRisksHubSection: View {
    @Bindable var project: Project
    var modelContext: ModelContext
    var streakStore: StreakStore

    @State private var selected: ProjectRisk?
    @State private var showAdd = false
    @State private var addTitle = ""

    private var sortedRisks: [ProjectRisk] {
        project.risks.sorted { $0.title < $1.title }
    }

    var body: some View {
        Group {
            if let r = selected {
                riskDetail(r)
            } else {
                List(selection: $selected) {
                    ForEach(sortedRisks) { row in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.title).font(.headline)
                            Text("L\(row.likelihood) · I\(row.impact) · \(row.status)")
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
            VStack(alignment: .leading, spacing: 12) {
                Text("Risk").font(.headline)
                TextField("Title", text: $addTitle).textFieldStyle(.roundedBorder)
                HStack {
                    Spacer()
                    Button("Cancel") { showAdd = false }
                    Button("Add") {
                        let t = addTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !t.isEmpty else { return }
                        let risk = ProjectRisk(title: t, project: project)
                        modelContext.insert(risk)
                        project.risks.append(risk)
                        try? modelContext.save()
                        streakStore.recordUsage()
                        showAdd = false
                        addTitle = ""
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(minWidth: 300)
        }
        .toolbar {
            if selected == nil {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add risk") { showAdd = true }
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
                            selected = nil
                            try? modelContext.save()
                            streakStore.recordUsage()
                        }
                    }
                }
            }
        }
    }

    private func riskDetail(_ r: ProjectRisk) -> some View {
        @Bindable var r = r
        return Form {
            TextField("Title", text: $r.title)
            Stepper("Likelihood: \(r.likelihood)", value: $r.likelihood, in: 1...5)
            Stepper("Impact: \(r.impact)", value: $r.impact, in: 1...5)
            TextField("Status", text: $r.status)
            TextEditor(text: $r.detail)
                .frame(minHeight: 80)
            TextEditor(text: $r.mitigation)
                .frame(minHeight: 80)
        }
        .formStyle(.grouped)
        .padding()
        .onDisappear { try? modelContext.save() }
    }

    private func deleteAt(_ offsets: IndexSet) {
        for index in offsets {
            let r = sortedRisks[index]
            if selected?.persistentModelID == r.persistentModelID { selected = nil }
            modelContext.delete(r)
        }
        try? modelContext.save()
        streakStore.recordUsage()
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
