import SwiftUI
import AppKit

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
    @AppStorage(AppSoundSettings.countdownSoundKey) private var countdownSoundName: String = AppSoundSettings.defaultSoundName

    var body: some View {
        Form {
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
    }

    private func previewSound(named name: String) {
        guard name != "None" else { return }
        if let sound = NSSound(named: name) {
            sound.play()
        }
    }
}

#Preview {
    SettingsView()
}
