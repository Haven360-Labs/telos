import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

// MARK: - Notification preferences (UserDefaults)
enum AppNotificationSettings {
    static let countdownFinishedKey = "telos.notifications.countdownFinished"
    static let morningReminderEnabledKey = "telos.notifications.morningReminderEnabled"
    static let morningReminderHourKey = "telos.morningReminderHour"
    static let morningReminderMinuteKey = "telos.morningReminderMinute"
    static let endOfDayReminderEnabledKey = "telos.notifications.endOfDayReminderEnabled"
    static let endOfDayReminderHourKey = "telos.endOfDayReminderHour"
    static let endOfDayReminderMinuteKey = "telos.endOfDayReminderMinute"

    static var countdownFinishedEnabled: Bool {
        get { UserDefaults.standard.object(forKey: countdownFinishedKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: countdownFinishedKey) }
    }
    static var morningReminderEnabled: Bool {
        get { UserDefaults.standard.object(forKey: morningReminderEnabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: morningReminderEnabledKey) }
    }
    static var morningReminderHour: Int {
        get { UserDefaults.standard.object(forKey: morningReminderHourKey) as? Int ?? 8 }
        set { UserDefaults.standard.set(newValue, forKey: morningReminderHourKey) }
    }
    static var morningReminderMinute: Int {
        get { UserDefaults.standard.object(forKey: morningReminderMinuteKey) as? Int ?? 0 }
        set { UserDefaults.standard.set(newValue, forKey: morningReminderMinuteKey) }
    }
    static var endOfDayReminderEnabled: Bool {
        get { UserDefaults.standard.object(forKey: endOfDayReminderEnabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: endOfDayReminderEnabledKey) }
    }
    static var endOfDayReminderHour: Int {
        get { UserDefaults.standard.object(forKey: endOfDayReminderHourKey) as? Int ?? 18 }
        set { UserDefaults.standard.set(newValue, forKey: endOfDayReminderHourKey) }
    }
    static var endOfDayReminderMinute: Int {
        get { UserDefaults.standard.object(forKey: endOfDayReminderMinuteKey) as? Int ?? 0 }
        set { UserDefaults.standard.set(newValue, forKey: endOfDayReminderMinuteKey) }
    }

    static let reminderHourRange = 0...23
    static let reminderMinuteChoices = [0, 15, 30, 45]
}

// MARK: - Menu bar label length (UserDefaults)
enum AppMenuBarSettings {
    static let labelLengthKey = "telos.menubar.labelLength"
    static let menuBarLabelLengthDidChangeNotification = Notification.Name("TelosMenuBarLabelLengthDidChange")

    enum LabelLength: String, CaseIterable {
        case short = "short"
        case long = "long"

        var displayName: String {
            switch self {
            case .short: return "Short"
            case .long: return "Long"
            }
        }
    }

    static var labelLength: LabelLength {
        get {
            guard let raw = UserDefaults.standard.string(forKey: labelLengthKey),
                  let value = LabelLength(rawValue: raw) else { return .long }
            return value
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: labelLengthKey) }
    }
}

// MARK: - Sound preference (UserDefaults)
enum AppSoundSettings {
    static let countdownSoundKey = "telos.countdownSoundName"

    /// Sound name for countdown finished; nil or "None" = no sound; default "Glass".
    static var countdownSoundName: String? {
        get {
            let v = UserDefaults.standard.string(forKey: countdownSoundKey)
            return (v == nil || v == "" || v == "None") ? nil : v
        }
        set {
            UserDefaults.standard.set(newValue ?? "None", forKey: countdownSoundKey)
        }
    }

    /// Display name for "no sound" option.
    static let noneSoundDisplayName = "None"
    /// Default sound when no preference is set.
    static let defaultSoundName = "Glass"

    /// Built-in system sound names (without extension); "None" means no sound.
    static let availableCountdownSounds: [(id: String, displayName: String)] = [
        ("None", "None"),
        ("Glass", "Glass"),
        ("Ping", "Ping"),
        ("Pop", "Pop"),
        ("Purr", "Purr"),
        ("Submarine", "Submarine"),
        ("Funk", "Funk"),
        ("Blow", "Blow"),
        ("Bottle", "Bottle"),
        ("Hero", "Hero"),
        ("Morse", "Morse"),
        ("Tink", "Tink"),
    ]
}

// MARK: - Task defaults (UserDefaults)
enum AppTaskSettings {
    static let defaultQuadrantKey = "telos.tasks.defaultQuadrant"

    static var defaultQuadrant: EisenhowerQuadrant {
        get {
            let raw = UserDefaults.standard.object(forKey: defaultQuadrantKey) as? Int
            return EisenhowerQuadrant(rawValue: raw ?? EisenhowerQuadrant.notImportantNotUrgent.rawValue) ?? .notImportantNotUrgent
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultQuadrantKey)
        }
    }
}

struct SettingsView: View {
    @Environment(DayStore.self) private var dayStore
    @AppStorage(AppNotificationSettings.countdownFinishedKey) private var countdownFinishedEnabled: Bool = true
    @AppStorage(AppNotificationSettings.morningReminderEnabledKey) private var morningReminderEnabled: Bool = true
    @AppStorage(AppNotificationSettings.morningReminderHourKey) private var morningReminderHour: Int = 8
    @AppStorage(AppNotificationSettings.morningReminderMinuteKey) private var morningReminderMinute: Int = 0
    @AppStorage(AppNotificationSettings.endOfDayReminderEnabledKey) private var endOfDayReminderEnabled: Bool = true
    @AppStorage(AppNotificationSettings.endOfDayReminderHourKey) private var endOfDayReminderHour: Int = 18
    @AppStorage(AppNotificationSettings.endOfDayReminderMinuteKey) private var endOfDayReminderMinute: Int = 0
    @AppStorage(AppSoundSettings.countdownSoundKey) private var countdownSoundName: String = AppSoundSettings.defaultSoundName
    @AppStorage(AppMenuBarSettings.labelLengthKey) private var menuBarLabelLength: String = AppMenuBarSettings.LabelLength.long.rawValue
    @AppStorage(AppTaskSettings.defaultQuadrantKey) private var defaultTaskQuadrantRaw: Int = EisenhowerQuadrant.notImportantNotUrgent.rawValue

    var body: some View {
        Form {
            Section {
                Toggle("Timer finished", isOn: $countdownFinishedEnabled)
                Toggle("Morning reminder", isOn: $morningReminderEnabled)
                if morningReminderEnabled {
                    HStack(spacing: 12) {
                        Text("Morning reminder time")
                        Text(formattedTime(hour: morningReminderHour, minute: morningReminderMinute))
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 64, alignment: .leading)
                        Picker("Hour", selection: $morningReminderHour) {
                            ForEach(AppNotificationSettings.reminderHourRange, id: \.self) { h in
                                Text(hourLabel(h)).tag(h)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 90)
                        Picker("Minute", selection: $morningReminderMinute) {
                            ForEach(AppNotificationSettings.reminderMinuteChoices, id: \.self) { m in
                                Text(minuteLabel(m)).tag(m)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 70)
                    }
                    .onChange(of: morningReminderHour) { _, _ in dayStore.scheduleMorningReminder() }
                    .onChange(of: morningReminderMinute) { _, _ in dayStore.scheduleMorningReminder() }
                }
                Toggle("Evening reminder", isOn: $endOfDayReminderEnabled)
                if endOfDayReminderEnabled {
                    HStack(spacing: 12) {
                        Text("Evening reminder time")
                        Text(formattedTime(hour: endOfDayReminderHour, minute: endOfDayReminderMinute))
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 64, alignment: .leading)
                        Picker("Hour", selection: $endOfDayReminderHour) {
                            ForEach(AppNotificationSettings.reminderHourRange, id: \.self) { h in
                                Text(hourLabel(h)).tag(h)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 90)
                        Picker("Minute", selection: $endOfDayReminderMinute) {
                            ForEach(AppNotificationSettings.reminderMinuteChoices, id: \.self) { m in
                                Text(minuteLabel(m)).tag(m)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 70)
                    }
                }
            } header: {
                Text("Notifications")
            } footer: {
                Text("Timer finished: system notification when a countdown reaches zero. Morning reminder: daily at the set time. Evening reminder: when you open Telos after the set time, if you have incomplete tasks.")
            }
            .onChange(of: morningReminderEnabled) { _, _ in dayStore.scheduleMorningReminder() }

            Section {
                Picker("Menu bar label", selection: $menuBarLabelLength) {
                    ForEach(AppMenuBarSettings.LabelLength.allCases, id: \.rawValue) { length in
                        Text(length.displayName).tag(length.rawValue)
                    }
                }
                .onChange(of: menuBarLabelLength) { _, _ in
                    NotificationCenter.default.post(name: AppMenuBarSettings.menuBarLabelLengthDidChangeNotification, object: nil)
                }
            } header: {
                Text("Menu bar")
            } footer: {
                Text("Short: time and task name only. Long: includes total time today and paused state.")
            }

            Section {
                Picker("Countdown finished sound", selection: $countdownSoundName) {
                    ForEach(AppSoundSettings.availableCountdownSounds, id: \.id) { sound in
                        Text(sound.displayName).tag(sound.id)
                    }
                }
                .onChange(of: countdownSoundName) { _, newValue in
                    if newValue != "None", !newValue.isEmpty {
                        previewSound(named: newValue)
                    }
                }
                Button("Preview sound") {
                    let name = (countdownSoundName.isEmpty || countdownSoundName == "None") ? AppSoundSettings.defaultSoundName : countdownSoundName
                    previewSound(named: name)
                }
                .disabled(countdownSoundName == "None")
            } header: {
                Text("Timer")
            } footer: {
                Text("Plays when a countdown timer reaches zero.")
            }

            Section {
                Picker("Default task type", selection: $defaultTaskQuadrantRaw) {
                    ForEach(EisenhowerQuadrant.matrixDisplayOrder, id: \.rawValue) { q in
                        Text(q.shortTitle).tag(q.rawValue)
                    }
                }
            } header: {
                Text("Tasks")
            } footer: {
                Text("Used as the preselected type when creating new tasks.")
            }

            BackupRecoverySettingsSection()
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .onAppear {
            if UserDefaults.standard.object(forKey: AppNotificationSettings.morningReminderHourKey) == nil {
                morningReminderHour = 8
                morningReminderMinute = 0
            }
            if UserDefaults.standard.object(forKey: AppNotificationSettings.endOfDayReminderHourKey) == nil {
                endOfDayReminderHour = 18
                endOfDayReminderMinute = 0
            }
            // Clamp minute to a valid picker choice so the menu selection displays
            if !AppNotificationSettings.reminderMinuteChoices.contains(morningReminderMinute) {
                morningReminderMinute = AppNotificationSettings.reminderMinuteChoices.min(by: { abs($0 - morningReminderMinute) < abs($1 - morningReminderMinute) }) ?? 0
            }
            if !AppNotificationSettings.reminderMinuteChoices.contains(endOfDayReminderMinute) {
                endOfDayReminderMinute = AppNotificationSettings.reminderMinuteChoices.min(by: { abs($0 - endOfDayReminderMinute) < abs($1 - endOfDayReminderMinute) }) ?? 0
            }
        }
    }

    private func previewSound(named name: String) {
        guard name != "None" else { return }
        if let sound = NSSound(named: name) {
            sound.play()
        }
    }

    private func hourLabel(_ h: Int) -> String {
        if h == 0 { return "12 AM" }
        if h == 12 { return "12 PM" }
        if h < 12 { return "\(h) AM" }
        return "\(h - 12) PM"
    }

    private func minuteLabel(_ m: Int) -> String {
        String(format: "%02d", m)
    }

    private func formattedTime(hour: Int, minute: Int) -> String {
        let h = max(0, min(23, hour))
        let m = max(0, min(59, minute))
        if h == 0 { return String(format: "12:%02d AM", m) }
        if h == 12 { return String(format: "12:%02d PM", m) }
        if h < 12 { return String(format: "%d:%02d AM", h, m) }
        return String(format: "%d:%02d PM", h - 12, m)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TelosModelSchema.schema, configurations: [config])
    return SettingsView()
        .environment(DayStore())
        .modelContainer(container)
}

// MARK: - Backup & recovery

private struct BackupRecoverySettingsSection: View {
    @Environment(\.modelContext) private var modelContext
    @State private var localBackupFolders: [URL] = []
    @State private var iCloudBackupFolders: [URL] = []
    @State private var showRestoreLocal = false
    @State private var showRestoreICloud = false
    @State private var resultAlertTitle = ""
    @State private var resultAlertMessage = ""
    @State private var showResultAlert = false

    private var iCloudAvailable: Bool {
        TelosBackupCoordinator.shared.iCloudBackupsRoot() != nil
    }

    var body: some View {
        Section {
            Button("Back up now") {
                do {
                    try TelosBackupCoordinator.shared.backupNow(modelContext: modelContext)
                    presentResult(title: "Backup complete", message: "A new backup was saved locally and copied to iCloud if available.")
                } catch {
                    presentResult(title: "Backup failed", message: error.localizedDescription)
                }
            }
            Button("Export full backup to file…") {
                exportFullBackupToFile()
            }
            Button("Import full backup from file…") {
                importFullBackupFromFile()
            }
            Button("Restore from local backup…") {
                localBackupFolders = TelosBackupCoordinator.shared.listLocalBackupFolders()
                showRestoreLocal = true
            }
            Button("Restore from iCloud backup…") {
                iCloudBackupFolders = TelosBackupCoordinator.shared.listICloudBackupFolders()
                showRestoreICloud = true
            }
            .disabled(!iCloudAvailable)
            Button("Open backups folder in Finder") {
                TelosBackupCoordinator.shared.openLocalBackupsFolder()
            }
            if !iCloudAvailable {
                Text("iCloud Drive is unavailable. Sign in to iCloud to mirror backups to Documents/TelosBackups. Local backups still work.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Backup & recovery")
        } footer: {
            Text("Keeps up to 7 timestamped backups under Application Support/com.telos.app/Backups (SQLite + JSON). Restoring replaces all current data.")
        }
        .sheet(isPresented: $showRestoreLocal) {
            backupPickerSheet(folders: localBackupFolders, title: "Local backups", isPresented: $showRestoreLocal)
        }
        .sheet(isPresented: $showRestoreICloud) {
            backupPickerSheet(folders: iCloudBackupFolders, title: "iCloud backups", isPresented: $showRestoreICloud)
        }
        .alert(resultAlertTitle, isPresented: $showResultAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(resultAlertMessage)
        }
    }

    private func presentResult(title: String, message: String) {
        resultAlertTitle = title
        resultAlertMessage = message
        showResultAlert = true
    }

    private func exportFullBackupToFile() {
        do {
            let data = try TelosFullBackup.exportSnapshotJSON(modelContext: modelContext)
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = "telos-backup.json"
            panel.title = "Export full backup"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            try data.write(to: url, options: .atomic)
            presentResult(title: "Export complete", message: "Saved to \(url.path)")
        } catch {
            presentResult(title: "Export failed", message: error.localizedDescription)
        }
    }

    private func importFullBackupFromFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = "Import full backup"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard confirmDestructiveRestore() else { return }
        do {
            let data = try Data(contentsOf: url)
            try TelosFullBackup.importSnapshot(data: data, modelContext: modelContext)
            presentResult(title: "Import complete", message: "All data was replaced from the backup file.")
        } catch {
            presentResult(title: "Import failed", message: error.localizedDescription)
        }
    }

    private func confirmDestructiveRestore() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Replace all Telos data?"
        alert.informativeText = "This removes every plan, project, note, and challenge in the app and replaces them with the backup. This cannot be undone."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Replace All Data")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func restore(from folder: URL) {
        guard confirmDestructiveRestore() else { return }
        let jsonURL = folder.appendingPathComponent(TelosStoreLocation.snapshotFileName)
        do {
            let data = try Data(contentsOf: jsonURL)
            try TelosFullBackup.importSnapshot(data: data, modelContext: modelContext)
            presentResult(title: "Restore complete", message: "All data was replaced from the selected backup.")
        } catch {
            presentResult(title: "Restore failed", message: error.localizedDescription)
        }
    }

    @ViewBuilder
    private func backupPickerSheet(folders: [URL], title: String, isPresented: Binding<Bool>) -> some View {
        NavigationStack {
            List {
                if folders.isEmpty {
                    Text("No backups found.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(folders, id: \.path) { folder in
                        Button {
                            isPresented.wrappedValue = false
                            restore(from: folder)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(folder.lastPathComponent)
                                    .font(.body)
                                HStack {
                                    if let exported = TelosBackupCoordinator.readSnapshotExportedAt(folder: folder) {
                                        Text(exported.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    let bytes = TelosBackupCoordinator.folderByteSize(folder)
                                    Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented.wrappedValue = false }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 320)
    }
}
