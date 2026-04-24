import SwiftUI
import SwiftData
import UserNotifications

@main
struct TelosApp: App {
    @State private var dayStore = DayStore()
    @State private var timerStore = TimerStore()
    @State private var streakStore = StreakStore()
    @State private var projectBoardNavigation = ProjectBoardNavigationStore()

    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    var sharedModelContainer: ModelContainer = {
        TelosStoreLocation.prepareStoreDirectoryAndMigrateLegacyIfNeeded()
        // Phase 2 (live sync): add `cloudKitDatabase: .private("iCloud.com.telos.app")` after CloudKit schema exists in the Developer portal.
        let config = ModelConfiguration(url: TelosStoreLocation.storeURL)
        do {
            return try ModelContainer(for: TelosModelSchema.schema, configurations: [config])
        } catch {
            fatalError("SwiftData container failed to open persistent store: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(dayStore)
                .environment(timerStore)
                .environment(streakStore)
                .environment(projectBoardNavigation)
        }
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
