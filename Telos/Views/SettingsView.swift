import SwiftUI
import AppKit

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
    SettingsView()
        .environment(DayStore())
}
