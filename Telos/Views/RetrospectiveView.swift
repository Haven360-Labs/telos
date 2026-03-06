import SwiftUI
import SwiftData

enum RetrospectiveScope: String, CaseIterable, Identifiable {
    case day
    case week
    case month
    case quarter

    var id: String { rawValue }

    var label: String {
        switch self {
        case .day: return "Day"
        case .week: return "Week"
        case .month: return "Month"
        case .quarter: return "Quarter"
        }
    }

    /// (start, end) for the period containing `date`. end is exclusive.
    func periodRange(around date: Date, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let start: Date
        let end: Date
        switch self {
        case .day:
            start = calendar.startOfDay(for: date)
            end = calendar.date(byAdding: .day, value: 1, to: start)!
        case .week:
            start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
            end = calendar.date(byAdding: .day, value: 7, to: start)!
        case .month:
            start = calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
            end = calendar.date(byAdding: .month, value: 1, to: start)!
        case .quarter:
            let month = calendar.component(.month, from: date)
            let quarterStartMonth = ((month - 1) / 3) * 3 + 1
            var comps = calendar.dateComponents([.year], from: date)
            comps.month = quarterStartMonth
            comps.day = 1
            start = calendar.date(from: comps)!
            end = calendar.date(byAdding: .month, value: 3, to: start)!
        }
        return (start, end)
    }

    /// Period (start, end) for the given offset from today. 0 = current period, -1 = previous (e.g. last week/month), -2 = two periods ago.
    func periodRange(offsetFromToday offset: Int, calendar: Calendar = .current) -> (start: Date, end: Date) {
        if offset == 0 {
            return periodRange(around: Date(), calendar: calendar)
        }
        let (curStart, curEnd) = periodRange(around: Date(), calendar: calendar)
        if offset > 0 {
            var start = curStart
            var end = curEnd
            for _ in 0..<offset {
                start = end
                end = periodEnd(after: start, calendar: calendar)
            }
            return (start, end)
        }
        var start = curStart
        var end = curEnd
        for _ in 0..<(-offset) {
            end = start
            start = periodStart(before: end, calendar: calendar)
        }
        return (start, end)
    }

    private func periodEnd(after periodStart: Date, calendar: Calendar) -> Date {
        switch self {
        case .day: return calendar.date(byAdding: .day, value: 1, to: periodStart)!
        case .week: return calendar.date(byAdding: .day, value: 7, to: periodStart)!
        case .month: return calendar.date(byAdding: .month, value: 1, to: periodStart)!
        case .quarter: return calendar.date(byAdding: .month, value: 3, to: periodStart)!
        }
    }

    private func periodStart(before periodEnd: Date, calendar: Calendar) -> Date {
        switch self {
        case .day: return calendar.date(byAdding: .day, value: -1, to: periodEnd)!
        case .week: return calendar.date(byAdding: .day, value: -7, to: periodEnd)!
        case .month: return calendar.date(byAdding: .month, value: -1, to: periodEnd)!
        case .quarter: return calendar.date(byAdding: .month, value: -3, to: periodEnd)!
        }
    }
}

struct RetrospectiveView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StreakStore.self) private var streakStore
    @State private var scope: RetrospectiveScope = .week
    /// 0 = current period (e.g. this week), -1 = previous (last week/month), -2 = two periods ago.
    @State private var periodOffset: Int = 0
    @State private var periodDays: [PlanDay] = []
    @State private var entry: RetrospectiveEntry?

    private let calendar = Calendar.current

    var body: some View {
        let (start, end) = scope.periodRange(offsetFromToday: periodOffset, calendar: calendar)
        let periodTitle = periodTitle(start: start, end: end)
        let canGoNext = periodOffset < 0

        return List {
            Section {
                Picker("Scope", selection: $scope) {
                    ForEach(RetrospectiveScope.allCases) { s in
                        Text(s.label).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: scope) {
                    periodOffset = 0
                    loadData()
                }
            }

            Section {
                HStack {
                    Label(periodTitle, systemImage: "calendar")
                        .font(.subheadline)
                    Spacer()
                    HStack(spacing: 12) {
                        Button {
                            periodOffset -= 1
                            loadData()
                        } label: {
                            Label("Previous \(scope.label)", systemImage: "chevron.left")
                                .labelStyle(.iconOnly)
                        }
                        .help("Previous \(scope.label.lowercased()) (e.g. last \(scope.label.lowercased()))")

                        Button {
                            periodOffset += 1
                            loadData()
                        } label: {
                            Label("Next \(scope.label)", systemImage: "chevron.right")
                                .labelStyle(.iconOnly)
                        }
                        .disabled(!canGoNext)
                        .help(canGoNext ? "Next \(scope.label.lowercased())" : "Current \(scope.label.lowercased())")
                    }
                }
            }

            Section("Metrics") {
                Label("Tasks completed: \(completedCount)", systemImage: "checkmark.circle.fill")
                Label("Tasks not completed: \(incompleteCount)", systemImage: "circle")
                Label("Time spent: \(formattedTimeSpent)", systemImage: "timer")
                Label("Days used: \(daysUsedInPeriod(start: start, end: end))", systemImage: "flame")
            }

            Section("What was done") {
                if completedTaskTitles.isEmpty {
                    Text("No completed tasks in this period.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(completedTaskTitles.enumerated()), id: \.offset) { _, title in
                        Text(title)
                    }
                }
            }

            Section("What wasn't") {
                if incompleteTaskTitles.isEmpty {
                    Text("No incomplete tasks in this period.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(incompleteTaskTitles.enumerated()), id: \.offset) { _, title in
                        Text(title)
                    }
                }
            }

            Section("Notes") {
                TextEditor(text: Binding(
                    get: { entry?.notes ?? "" },
                    set: { newValue in
                        if entry == nil {
                            let (s, _) = scope.periodRange(offsetFromToday: periodOffset, calendar: calendar)
                            let newEntry = RetrospectiveEntry(periodScope: scope.rawValue, periodStart: s, notes: newValue)
                            modelContext.insert(newEntry)
                            entry = newEntry
                        } else {
                            entry?.notes = newValue
                        }
                        try? modelContext.save()
                    }
                ))
                .frame(minHeight: 80)
            }
        }
        .listStyle(.inset)
        .navigationTitle("Retrospective")
        .onAppear {
            loadData()
            streakStore.recordUsage()
        }
        .onChange(of: periodOffset) { loadData() }
    }

    private var completedCount: Int {
        periodDays.flatMap(\.tasks).filter { !$0.isArchived && $0.isCompleted }.count
    }

    private var incompleteCount: Int {
        periodDays.flatMap(\.tasks).filter { !$0.isArchived && !$0.isCompleted }.count
    }

    private var totalTimeSpentSeconds: Double {
        periodDays.flatMap(\.tasks).reduce(0) { $0 + $1.timeSpentSeconds }
    }

    private var formattedTimeSpent: String {
        let total = Int(totalTimeSpentSeconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private var completedTaskTitles: [String] {
        periodDays.flatMap(\.tasks)
            .filter { !$0.isArchived && $0.isCompleted }
            .map(\.title)
    }

    private var incompleteTaskTitles: [String] {
        periodDays.flatMap(\.tasks)
            .filter { !$0.isArchived && !$0.isCompleted }
            .map(\.title)
    }

    private func periodTitle(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        if scope == .day {
            return formatter.string(from: start)
        }
        let endPrev = calendar.date(byAdding: .day, value: -1, to: end)!
        return "\(formatter.string(from: start)) – \(formatter.string(from: endPrev))"
    }

    private func daysUsedInPeriod(start: Date, end: Date) -> Int {
        streakStore.usedDaysCount(from: start, to: end)
    }

    private func loadData() {
        let (start, end) = scope.periodRange(offsetFromToday: periodOffset, calendar: calendar)
        let scopeRaw = scope.rawValue
        let descriptor = FetchDescriptor<PlanDay>(
            predicate: #Predicate<PlanDay> { day in
                day.date >= start && day.date < end
            },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        periodDays = (try? modelContext.fetch(descriptor)) ?? []

        var entryDescriptor = FetchDescriptor<RetrospectiveEntry>(
            predicate: #Predicate<RetrospectiveEntry> { e in
                e.periodScope == scopeRaw && e.periodStart == start
            }
        )
        entryDescriptor.fetchLimit = 1
        entry = (try? modelContext.fetch(entryDescriptor))?.first
    }
}
