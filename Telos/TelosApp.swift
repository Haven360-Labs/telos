import SwiftUI
import SwiftData
import UserNotifications

@main
struct TelosApp: App {
    @State private var dayStore = DayStore()
    @State private var timerStore = TimerStore()
    @State private var streakStore = StreakStore()

    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([PlanDay.self, PlanTask.self, PlanNote.self, RetrospectiveEntry.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(dayStore)
                .environment(timerStore)
                .environment(streakStore)
        }
        .modelContainer(sharedModelContainer)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
