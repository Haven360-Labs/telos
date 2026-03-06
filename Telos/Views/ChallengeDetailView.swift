import SwiftUI
import SwiftData
import AppKit

struct ChallengeDetailView: View {
    @Bindable var challenge: Challenge
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selectedDaySheet: DaySheetItem?
    @State private var selectedPeriodSheet: PeriodSheetItem?
    @State private var showEditSheet = false

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 14)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                trackSection
                retrospectivesSection
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(.regularMaterial.opacity(0.3))
        .sheet(item: $selectedDaySheet) { item in
            DayProgressSheet(
                challenge: challenge,
                dayIndex: item.dayIndex,
                existingProgress: progress(forDay: item.dayIndex),
                onSave: { notes, isCompleted in
                    saveDayProgress(dayIndex: item.dayIndex, notes: notes, isCompleted: isCompleted)
                    selectedDaySheet = nil
                },
                onCancel: { selectedDaySheet = nil }
            )
            .frame(minWidth: 400, minHeight: 260)
            .presentationCornerRadius(12)
        }
        .sheet(item: $selectedPeriodSheet) { item in
            ChallengeRetrospectiveSheet(
                challenge: challenge,
                periodIndex: item.periodIndex,
                existingNotes: retrospectiveNotes(forPeriod: item.periodIndex),
                onSave: { notes in
                    saveRetrospective(periodIndex: item.periodIndex, notes: notes)
                    selectedPeriodSheet = nil
                },
                onCancel: { selectedPeriodSheet = nil }
            )
            .frame(minWidth: 440, minHeight: 320)
            .presentationCornerRadius(12)
        }
        .sheet(isPresented: $showEditSheet) {
            EditChallengeSheet(
                challenge: challenge,
                onSave: { newTitle, newDescription, newTotalDays, newRetrospectivePeriodDays, allowMarkPastDays, excludeWeekends in
                    applyEdit(title: newTitle, challengeDescription: newDescription, totalDays: newTotalDays, retrospectivePeriodDays: newRetrospectivePeriodDays, allowMarkPastDays: allowMarkPastDays, excludeWeekends: excludeWeekends)
                    showEditSheet = false
                },
                onCancel: { showEditSheet = false }
            )
            .frame(minWidth: 400, minHeight: 380)
            .presentationCornerRadius(12)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showEditSheet = true
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    deleteChallenge()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }

    private func applyEdit(title: String, challengeDescription: String, totalDays: Int, retrospectivePeriodDays: Int, allowMarkPastDays: Bool, excludeWeekends: Bool) {
        let newTotal = min(max(totalDays, 1), 365)
        challenge.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        challenge.challengeDescription = challengeDescription.isEmpty ? nil : challengeDescription
        challenge.retrospectivePeriodDays = retrospectivePeriodDays
        challenge.allowMarkPastDays = allowMarkPastDays
        challenge.excludeWeekends = excludeWeekends
        if newTotal != challenge.totalDays, newTotal < challenge.totalDays {
            let toRemoveProgress = challenge.dayProgress.filter { $0.dayIndex > newTotal }
            for p in toRemoveProgress { modelContext.delete(p) }
            let period = challenge.effectiveRetrospectivePeriodDays
            let newPeriodCount = (newTotal + period - 1) / period
            let toRemoveRetro = challenge.retrospectives.filter { $0.periodIndex > newPeriodCount }
            for r in toRemoveRetro { modelContext.delete(r) }
        }
        challenge.totalDays = newTotal
        try? modelContext.save()
    }

    private func deleteChallenge() {
        modelContext.delete(challenge)
        try? modelContext.save()
        dismiss()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(challenge.title)
                .font(.title2)
                .fontWeight(.semibold)
            if let desc = challenge.challengeDescription, !desc.isEmpty {
                Text(desc)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Text("\(challenge.totalDays) day challenge")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Started \(challenge.startDate, style: .date)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            let completed = challenge.completedReachedCount(calendar: calendar)
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("\(completed)/\(challenge.totalDays) days with progress")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var trackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Track")
                    .font(.headline)
                Spacer()
                Text("Tap a day to add progress")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(1...challenge.totalDays, id: \.self) { dayIndex in
                    DayTrackCell(
                        dayIndex: dayIndex,
                        isCompleted: isDayReached(dayIndex) ? (progress(forDay: dayIndex)?.isCompleted ?? false) : false,
                        hasNotes: !(progress(forDay: dayIndex)?.notes ?? "").isEmpty,
                        isPastAndNotCompleted: isDayPast(dayIndex) && (progress(forDay: dayIndex)?.isCompleted != true)
                    ) {
                        selectedDaySheet = DaySheetItem(dayIndex: dayIndex)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var retrospectivesSection: some View {
        let periodDays = challenge.effectiveRetrospectivePeriodDays
        return VStack(alignment: .leading, spacing: 12) {
            Text("Retrospectives (every \(periodDays) days)")
                .font(.headline)
            Text("Review how the challenge is going every \(periodDays) days.")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(1...challenge.biweeklyPeriodCount, id: \.self) { periodIndex in
                if let range = challenge.biweeklyPeriodDayRange(periodIndex: periodIndex) {
                    RetrospectiveRowView(
                        periodIndex: periodIndex,
                        dayRange: "Days \(range.start)–\(range.end)",
                        hasNotes: !retrospectiveNotes(forPeriod: periodIndex).isEmpty
                    ) {
                        selectedPeriodSheet = PeriodSheetItem(periodIndex: periodIndex)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func progress(forDay dayIndex: Int) -> ChallengeDayProgress? {
        challenge.dayProgress.first { $0.dayIndex == dayIndex }
    }

    private func isDayReached(_ dayIndex: Int) -> Bool {
        guard let date = challenge.date(forDayIndex: dayIndex) else { return false }
        return calendar.startOfDay(for: date) <= calendar.startOfDay(for: Date())
    }

    /// True when the day's date is strictly before today (past, not today).
    private func isDayPast(_ dayIndex: Int) -> Bool {
        guard let date = challenge.date(forDayIndex: dayIndex) else { return false }
        return calendar.startOfDay(for: date) < calendar.startOfDay(for: Date())
    }

    private func retrospectiveNotes(forPeriod periodIndex: Int) -> String {
        challenge.retrospectives.first { $0.periodIndex == periodIndex }?.notes ?? ""
    }

    private func saveDayProgress(dayIndex: Int, notes: String, isCompleted: Bool) {
        if let existing = progress(forDay: dayIndex) {
            existing.notes = notes
            existing.isCompleted = isCompleted
            existing.updatedAt = Date()
        } else {
            let p = ChallengeDayProgress(dayIndex: dayIndex, notes: notes, isCompleted: isCompleted, challenge: challenge)
            modelContext.insert(p)
            challenge.dayProgress.append(p)
        }
        try? modelContext.save()
    }

    private func saveRetrospective(periodIndex: Int, notes: String) {
        if let existing = challenge.retrospectives.first(where: { $0.periodIndex == periodIndex }) {
            existing.notes = notes
            existing.updatedAt = Date()
        } else {
            let r = ChallengeRetrospective(periodIndex: periodIndex, notes: notes, challenge: challenge)
            modelContext.insert(r)
            challenge.retrospectives.append(r)
        }
        try? modelContext.save()
    }
}

// MARK: - Day track cell

struct DayTrackCell: View {
    let dayIndex: Int
    let isCompleted: Bool
    let hasNotes: Bool
    /// True when the day is in the past and was not marked as done (missed day).
    let isPastAndNotCompleted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(cellColor)
                Text("\(dayIndex)")
                    .font(.system(.caption2, design: .rounded))
                    .fontWeight(hasNotes ? .medium : .regular)
                    .foregroundStyle(textColor)
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
    }

    private var cellColor: Color {
        if isPastAndNotCompleted { return Color.red }
        if isCompleted { return Color.green }
        if hasNotes { return Color.green.opacity(0.4) }
        return Color.gray.opacity(0.25)
    }

    private var textColor: Color {
        if isPastAndNotCompleted || isCompleted { return .white }
        return .primary
    }
}

// MARK: - Retrospective row

struct RetrospectiveRowView: View {
    let periodIndex: Int
    let dayRange: String
    let hasNotes: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Period \(periodIndex)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(dayRange)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if hasNotes {
                    Image(systemName: "text.alignleft")
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Left-aligned notes field (macOS Form often ignores SwiftUI alignment)

private struct LeadingAlignNotesField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var lineLimit: ClosedRange<Int> = 3...6

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }
        textView.font = .systemFont(ofSize: NSFont.systemFontSize)
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.isEditable = true
        textView.isSelectable = true
        textView.string = text
        textView.alignment = .left
        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        textView.alignment = .left
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        weak var textView: NSTextView?

        init(text: Binding<String>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
        }
    }
}

// MARK: - Day progress sheet

struct DayProgressSheet: View {
    let challenge: Challenge
    let dayIndex: Int
    let existingProgress: ChallengeDayProgress?
    let onSave: (String, Bool) -> Void
    let onCancel: () -> Void

    @State private var notes: String = ""
    @State private var isCompleted: Bool = true

    private var calendar: Calendar { .current }
    private var todayStart: Date { calendar.startOfDay(for: Date()) }

    private var isDayReached: Bool {
        guard let date = challenge.date(forDayIndex: dayIndex) else { return false }
        return calendar.startOfDay(for: date) <= todayStart
    }

    private var isDayPast: Bool {
        guard let date = challenge.date(forDayIndex: dayIndex) else { return false }
        return calendar.startOfDay(for: date) < todayStart
    }

    private var alreadyCompleted: Bool {
        existingProgress?.isCompleted == true
    }

    /// User can mark this day as done only if: future (no), today (yes), or past and (challenge allows OR already marked).
    private var canMarkAsDone: Bool {
        guard isDayReached else { return false }
        if !isDayPast { return true }
        return challenge.allowsMarkingPastDays || alreadyCompleted
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Day \(dayIndex) of \(challenge.totalDays)")
                        .font(.subheadline)
                    if let date = challenge.date(forDayIndex: dayIndex) {
                        Text(date, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Progress") {
                    Toggle("Mark day as done", isOn: $isCompleted)
                        .disabled(!canMarkAsDone)
                    if !isDayReached {
                        Text("You can mark this day when it has been reached.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if isDayPast && !challenge.allowsMarkingPastDays && !alreadyCompleted {
                        Text("Past days cannot be marked as done for this challenge (change in Edit).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    LeadingAlignNotesField(placeholder: "Notes (optional)", text: $notes, lineLimit: 3...6)
                        .frame(minHeight: 72, maxHeight: 140)
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            .formStyle(.grouped)
            .navigationTitle("Day \(dayIndex)")
            .onAppear {
                notes = existingProgress?.notes ?? ""
                isCompleted = canMarkAsDone ? (existingProgress?.isCompleted ?? true) : false
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let completed: Bool
                        if !isDayReached {
                            completed = false
                        } else if isDayPast && !challenge.allowsMarkingPastDays && !alreadyCompleted {
                            completed = false
                        } else {
                            completed = isCompleted
                        }
                        onSave(notes.trimmingCharacters(in: .whitespacesAndNewlines), completed)
                    }
                }
            }
        }
    }
}

// MARK: - Challenge retrospective sheet

struct ChallengeRetrospectiveSheet: View {
    let challenge: Challenge
    let periodIndex: Int
    let existingNotes: String
    let onSave: (String) -> Void
    let onCancel: () -> Void

    @State private var notes: String = ""

    private var dayRangeText: String {
        guard let range = challenge.biweeklyPeriodDayRange(periodIndex: periodIndex) else { return "" }
        return "Days \(range.start)–\(range.end)"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(dayRangeText)
                        .font(.subheadline)
                    Text("How is the challenge going? What worked, what didn’t, and what will you change?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section("Retrospective notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 160, alignment: .topLeading)
                        .multilineTextAlignment(.leading)
                }
            }
            .environment(\.layoutDirection, .leftToRight)
            .formStyle(.grouped)
            .navigationTitle("Retrospective")
            .onAppear {
                notes = existingNotes
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(notes.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                }
            }
        }
    }
}

// MARK: - Sheet selection wrappers (Identifiable for sheet(item:))

private struct DaySheetItem: Identifiable {
    let dayIndex: Int
    var id: Int { dayIndex }
}

private struct PeriodSheetItem: Identifiable {
    let periodIndex: Int
    var id: Int { periodIndex }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Challenge.self, ChallengeDayProgress.self, ChallengeRetrospective.self, configurations: config)
    let challenge = Challenge(title: "Preview challenge", challengeDescription: "A sample challenge for preview.", totalDays: 30, startDate: Date())
    container.mainContext.insert(challenge)
    return ChallengeDetailView(challenge: challenge)
        .modelContainer(container)
}
