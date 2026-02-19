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
        let schema = Schema([PlanDay.self, PlanTask.self, PlanNote.self, RetrospectiveEntry.self, Challenge.self, ChallengeDayProgress.self, ChallengeRetrospective.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            assertionFailure("SwiftData container failed: \(error). Using in-memory store.")
            let fallbackConfig = ModelConfiguration(isStoredInMemoryOnly: true)
            return (try? ModelContainer(for: schema, configurations: [fallbackConfig]))!
        }
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
