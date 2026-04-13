import SwiftUI
import SwiftData

// MARK: - Kanban card inspector (RICE, WSJF, checklist)

struct KanbanCardInspectorSheet: View {
    @Bindable var card: ProjectKanbanCard
    var project: Project?
    var modelContext: ModelContext
    var streakStore: StreakStore
    var onDismiss: () -> Void

    @State private var newChecklistTitle = ""

    private var sortedMilestones: [ProjectMilestone] {
        (project?.milestones ?? []).sorted { $0.targetDate < $1.targetDate }
    }

    private var sortedChecklist: [ProjectKanbanChecklistItem] {
        card.checklistItems.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        NavigationStack {
            Form {
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

// MARK: - Tasks (issues)

struct ProjectIssuesHubSection: View {
    @Bindable var project: Project
    var modelContext: ModelContext
    var streakStore: StreakStore

    @State private var selected: ProjectIssue?
    @State private var filterStatus = "all"
    @State private var showAdd = false

    private let statuses = ["all", "open", "in progress", "done", "closed"]

    private var sortedSprints: [ProjectSprint] {
        project.sprints.sorted { $0.startDate > $1.startDate }
    }

    private var sortedMilestones: [ProjectMilestone] {
        project.milestones.sorted { $0.targetDate < $1.targetDate }
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
                                if let ms = row.milestone {
                                    Text(ms.title)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
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
                sortedMilestones: sortedMilestones,
                sortedSprints: sortedSprints,
                allCards: allCards,
                onDismiss: { showAdd = false }
            )
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
            Picker("Milestone", selection: $issue.milestone) {
                Text("None").tag(nil as ProjectMilestone?)
                ForEach(sortedMilestones) { m in
                    Text(m.title.isEmpty ? "Milestone" : m.title).tag(m as ProjectMilestone?)
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
            Section {
                Stepper("Reach: \(issue.riceReach)", value: $issue.riceReach, in: 0...10)
                Stepper("Impact: \(issue.riceImpact)", value: $issue.riceImpact, in: 0...10)
                Stepper("Confidence: \(issue.riceConfidence)", value: $issue.riceConfidence, in: 0...10)
                Stepper("Effort: \(issue.riceEffort)", value: $issue.riceEffort, in: 0...10)
                if let r = KanbanCardScoring.riceScore(issue: issue) {
                    Text("RICE score: \(r, format: .number.precision(.fractionLength(2)))")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("RICE (1–10, 0 = unset)")
            }
            Section {
                TextField("Cost of delay", value: $issue.wsjfCostOfDelay, format: .number)
                TextField("Job size", value: $issue.wsjfJobSize, format: .number)
                if let w = KanbanCardScoring.wsjfScore(issue: issue) {
                    Text("WSJF score: \(w, format: .number.precision(.fractionLength(3)))")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("WSJF (0 = unset)")
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
    var sortedMilestones: [ProjectMilestone]
    var sortedSprints: [ProjectSprint]
    var allCards: [ProjectKanbanCard]
    var onDismiss: () -> Void

    @State private var title = ""
    @State private var detail = ""
    @State private var kind = "task"
    @State private var status = "open"
    @State private var priority = "medium"
    @State private var milestone: ProjectMilestone?
    @State private var sprint: ProjectSprint?
    @State private var card: ProjectKanbanCard?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("New task").font(.headline)
            TextField("Title", text: $title).textFieldStyle(.roundedBorder)
            TextField("Kind", text: $kind).textFieldStyle(.roundedBorder)
            TextField("Status", text: $status).textFieldStyle(.roundedBorder)
            TextField("Priority", text: $priority).textFieldStyle(.roundedBorder)
            Picker("Milestone", selection: $milestone) {
                Text("None").tag(nil as ProjectMilestone?)
                ForEach(sortedMilestones) { m in
                    Text(m.title.isEmpty ? "Milestone" : m.title).tag(m as ProjectMilestone?)
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
                        epic: nil,
                        sprint: sprint,
                        kanbanCard: card,
                        milestone: milestone
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
