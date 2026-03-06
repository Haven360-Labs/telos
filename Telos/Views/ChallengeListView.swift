import SwiftUI
import SwiftData

struct ChallengeListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Challenge.startDate, order: .reverse) private var challenges: [Challenge]
    @State private var showNewChallenge = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if challenges.isEmpty {
                        ContentUnavailableView(
                            "No challenges yet",
                            systemImage: "flag.checkered",
                            description: Text("Create a 30-day or 100-day challenge to track progress and add retrospectives every 3, 7, or 14 days.")
                        )
                    } else {
                        List {
                            ForEach(challenges) { challenge in
                                NavigationLink {
                                    ChallengeDetailView(challenge: challenge)
                                } label: {
                                    ChallengeRowView(challenge: challenge)
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        deleteChallenge(challenge)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(.inset)
                    }
                }
                Button {
                    showNewChallenge = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(.tint, in: Circle())
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .padding(24)
            }
        }
        .navigationTitle("Challenges")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showNewChallenge = true
                } label: {
                    Label("New challenge", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showNewChallenge) {
            NewChallengeSheet(onCreate: { title, challengeDescription, totalDays, retrospectivePeriodDays, allowMarkPastDays, excludeWeekends in
                createChallenge(title: title, challengeDescription: challengeDescription, totalDays: totalDays, retrospectivePeriodDays: retrospectivePeriodDays, allowMarkPastDays: allowMarkPastDays, excludeWeekends: excludeWeekends)
                showNewChallenge = false
            }, onCancel: {
                showNewChallenge = false
            })
            .frame(minWidth: 400, minHeight: 420)
            .presentationCornerRadius(12)
        }
    }

    private func createChallenge(title: String, challengeDescription: String = "", totalDays: Int, retrospectivePeriodDays: Int = 14, allowMarkPastDays: Bool = true, excludeWeekends: Bool = false) {
        let start = Calendar.current.startOfDay(for: Date())
        let challenge = Challenge(title: title, challengeDescription: challengeDescription, totalDays: totalDays, startDate: start, allowMarkPastDays: allowMarkPastDays, excludeWeekends: excludeWeekends, retrospectivePeriodDays: retrospectivePeriodDays)
        modelContext.insert(challenge)
        try? modelContext.save()
    }

    private func deleteChallenge(_ challenge: Challenge) {
        modelContext.delete(challenge)
        try? modelContext.save()
    }
}

struct ChallengeRowView: View {
    let challenge: Challenge

    private var completedCount: Int {
        challenge.completedReachedCount()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(challenge.title)
                .font(.headline)
            HStack(spacing: 12) {
                Text("\(challenge.totalDays) days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Day \(completedCount)/\(challenge.totalDays)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - New challenge sheet

private let retrospectivePeriodOptions = [3, 7, 14]

struct NewChallengeSheet: View {
    @State private var title = ""
    @State private var challengeDescription = ""
    @State private var totalDays = 30
    @State private var daysText = "30"
    @State private var retrospectivePeriodDays = 14
    @State private var allowMarkPastDays = true
    @State private var excludeWeekends = false
    var onCreate: (String, String, Int, Int, Bool, Bool) -> Void
    var onCancel: () -> Void

    private static let minDays = 1
    private static let maxDays = 365

    private var resolvedDays: Int {
        min(max(Int(daysText) ?? totalDays, Self.minDays), Self.maxDays)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Challenge name", text: $title)
                    TextField("Description (optional)", text: $challengeDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section {
                    HStack(spacing: 12) {
                        Text("Number of days")
                            .fixedSize(horizontal: true, vertical: false)
                            .frame(minWidth: 120, alignment: .leading)
                        HStack(spacing: 8) {
                            TextField("", text: $daysText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 56)
                                .multilineTextAlignment(.center)
                                .onChange(of: daysText) { _, newValue in
                                    let filtered = newValue.filter { $0.isNumber }
                                    if filtered != newValue { daysText = filtered }
                                    if let n = Int(filtered) {
                                        let clamped = min(max(n, Self.minDays), Self.maxDays)
                                        totalDays = clamped
                                        if n != clamped { daysText = String(clamped) }
                                    }
                                }
                            Stepper("", value: $totalDays, in: Self.minDays...Self.maxDays)
                                .labelsHidden()
                                .onChange(of: totalDays) { _, newValue in
                                    daysText = String(newValue)
                                }
                        }
                    }
                    Text("Between \(Self.minDays) and \(Self.maxDays) days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Duration")
                }
                Section {
                    Picker("Retrospective every", selection: $retrospectivePeriodDays) {
                        ForEach(retrospectivePeriodOptions, id: \.self) { days in
                            Text("\(days) days").tag(days)
                        }
                    }
                } header: {
                    Text("Retrospectives")
                } footer: {
                    Text("Review progress every 3, 7, or 14 days.")
                }
                Section {
                    Toggle("Exclude weekends", isOn: $excludeWeekends)
                } footer: {
                    Text("When on, only weekdays (Monday–Friday) count as challenge days; Saturday and Sunday are skipped.")
                }
                Section {
                    Toggle("Allow marking past days as done", isOn: $allowMarkPastDays)
                } footer: {
                    Text("When off, only the current day can be marked as done; past days that were not marked on the day cannot be marked later and will appear red in the track.")
                }
            }
            .formStyle(.grouped)
            .frame(minWidth: 380)
            .navigationTitle("New challenge")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !t.isEmpty {
                            let desc = challengeDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                            onCreate(t, desc.isEmpty ? "" : desc, resolvedDays, retrospectivePeriodDays, allowMarkPastDays, excludeWeekends)
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            daysText = String(totalDays)
        }
    }
}

// MARK: - Edit challenge sheet

struct EditChallengeSheet: View {
    let challenge: Challenge
    @State private var title: String = ""
    @State private var challengeDescription: String = ""
    @State private var totalDays: Int = 30
    @State private var daysText: String = "30"
    @State private var retrospectivePeriodDays: Int = 14
    @State private var allowMarkPastDays: Bool = true
    @State private var excludeWeekends: Bool = false
    var onSave: (String, String, Int, Int, Bool, Bool) -> Void
    var onCancel: () -> Void

    private static let minDays = 1
    private static let maxDays = 365

    private var resolvedDays: Int {
        min(max(Int(daysText) ?? totalDays, Self.minDays), Self.maxDays)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Challenge name", text: $title)
                    TextField("Description (optional)", text: $challengeDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section {
                    HStack(spacing: 12) {
                        Text("Number of days")
                            .fixedSize(horizontal: true, vertical: false)
                            .frame(minWidth: 120, alignment: .leading)
                        HStack(spacing: 8) {
                            TextField("", text: $daysText)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 56)
                                .multilineTextAlignment(.center)
                                .onChange(of: daysText) { _, newValue in
                                    let filtered = newValue.filter { $0.isNumber }
                                    if filtered != newValue { daysText = filtered }
                                    if let n = Int(filtered) {
                                        let clamped = min(max(n, Self.minDays), Self.maxDays)
                                        totalDays = clamped
                                        if n != clamped { daysText = String(clamped) }
                                    }
                                }
                            Stepper("", value: $totalDays, in: Self.minDays...Self.maxDays)
                                .labelsHidden()
                                .onChange(of: totalDays) { _, newValue in
                                    daysText = String(newValue)
                                }
                        }
                    }
                    Text("Between \(Self.minDays) and \(Self.maxDays) days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Duration")
                }
                Section {
                    Picker("Retrospective every", selection: $retrospectivePeriodDays) {
                        ForEach(retrospectivePeriodOptions, id: \.self) { days in
                            Text("\(days) days").tag(days)
                        }
                    }
                } header: {
                    Text("Retrospectives")
                } footer: {
                    Text("Review progress every 3, 7, or 14 days.")
                }
                Section {
                    Toggle("Exclude weekends", isOn: $excludeWeekends)
                } footer: {
                    Text("When on, only weekdays (Monday–Friday) count as challenge days; Saturday and Sunday are skipped.")
                }
                Section {
                    Toggle("Allow marking past days as done", isOn: $allowMarkPastDays)
                } footer: {
                    Text("When off, only the current day can be marked as done; past missed days will appear red in the track.")
                }
            }
            .formStyle(.grouped)
            .frame(minWidth: 380)
            .navigationTitle("Edit challenge")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !t.isEmpty {
                            onSave(t, challengeDescription.trimmingCharacters(in: .whitespacesAndNewlines), resolvedDays, retrospectivePeriodDays, allowMarkPastDays, excludeWeekends)
                        }
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            title = challenge.title
            challengeDescription = challenge.challengeDescription ?? ""
            totalDays = challenge.totalDays
            daysText = String(challenge.totalDays)
            retrospectivePeriodDays = challenge.effectiveRetrospectivePeriodDays
            allowMarkPastDays = challenge.allowsMarkingPastDays
            excludeWeekends = challenge.excludesWeekends
        }
    }
}

#Preview {
    ChallengeListView()
        .modelContainer(for: [Challenge.self, ChallengeDayProgress.self, ChallengeRetrospective.self], inMemory: true)
}
