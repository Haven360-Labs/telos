import Foundation
import SwiftData

/// Ensures the current calendar day exists and handles morning and end-of-day reminders.
@Observable
final class DayStore {
    private let calendar = Calendar.current
    private let userDefaultsKeyLastReminderDate = "telos.lastMorningReminderDate"
    private let userDefaultsKeyFirstLaunchToday = "telos.firstLaunchToday"
    private let userDefaultsKeyLastEndOfDayReminderDate = "telos.lastEndOfDayReminderDate"
    private let userDefaultsKeyEndOfDayReminderHour = "telos.endOfDayReminderHour"
    private let userDefaultsKeyEndOfDayReminderMinute = "telos.endOfDayReminderMinute"
    private let defaultEndOfDayHour = 18
    private let defaultEndOfDayMinute = 0

    /// Creates or fetches the plan day for the given date. Call at launch and when day changes.
    /// When a new day is created, incomplete tasks from yesterday are rolled over.
    func ensureTodayExists(modelContext: ModelContext) {
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        var descriptor = FetchDescriptor<PlanDay>(
            predicate: #Predicate<PlanDay> { day in
                day.date >= today && day.date < tomorrow
            }
        )
        descriptor.fetchLimit = 1
        let existingToday = try? modelContext.fetch(descriptor)
        if existingToday?.isEmpty == true {
            let todayDay = PlanDay(date: today, createdAt: Date())
            modelContext.insert(todayDay)
            try? modelContext.save()
            rollOverIncompleteTasks(from: yesterday, to: todayDay, modelContext: modelContext)
        }
    }

    /// Moves incomplete top-level tasks (and their subtasks) from yesterday's plan to today and marks them as rolled over.
    private func rollOverIncompleteTasks(from yesterdayStart: Date, to todayDay: PlanDay, modelContext: ModelContext) {
        let yesterdayEnd = calendar.date(byAdding: .day, value: 1, to: yesterdayStart)!
        var descriptor = FetchDescriptor<PlanDay>(
            predicate: #Predicate<PlanDay> { day in
                day.date >= yesterdayStart && day.date < yesterdayEnd
            }
        )
        descriptor.fetchLimit = 1
        guard let yesterdayPlan = (try? modelContext.fetch(descriptor))?.first else { return }
        let incompleteTopLevel = yesterdayPlan.tasks.filter { $0.parent == nil && !$0.isCompleted && !$0.isArchived }
        for task in incompleteTopLevel {
            task.planDay = todayDay
            task.isRolledOver = true
            for subtask in task.subtasks {
                subtask.planDay = todayDay
                subtask.isRolledOver = true
            }
        }
        try? modelContext.save()
    }

    /// Call when app becomes active or on wake: show at most one morning reminder per day.
    func showMorningReminderIfNeeded(modelContext: ModelContext) {
        let today = calendar.startOfDay(for: Date())
        let defaults = UserDefaults.standard
        if let last = defaults.object(forKey: userDefaultsKeyLastReminderDate) as? Date,
           calendar.isDate(last, inSameDayAs: today) {
            return
        }
        defaults.set(today, forKey: userDefaultsKeyLastReminderDate)
        requestMorningReminderNotification()
    }

    private func requestMorningReminderNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Good morning"
        content.body = "Review your day plan in Telos."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "telos.morning-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Call when app becomes active or on appear: show at most one end-of-day reminder per day
    /// if current time is at or past the configured end-of-day time and today has incomplete tasks.
    func showEndOfDayReminderIfNeeded(modelContext: ModelContext) {
        let today = calendar.startOfDay(for: Date())
        let now = Date()
        let hour = UserDefaults.standard.object(forKey: userDefaultsKeyEndOfDayReminderHour) as? Int ?? defaultEndOfDayHour
        let minute = UserDefaults.standard.object(forKey: userDefaultsKeyEndOfDayReminderMinute) as? Int ?? defaultEndOfDayMinute
        guard let endOfDayTime = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today),
              now >= endOfDayTime else { return }
        let defaults = UserDefaults.standard
        if let last = defaults.object(forKey: userDefaultsKeyLastEndOfDayReminderDate) as? Date,
           calendar.isDate(last, inSameDayAs: today) {
            return
        }
        guard let todayPlan = fetchToday(modelContext: modelContext),
              incompleteTopLevelTaskCount(planDay: todayPlan) > 0 else { return }
        defaults.set(today, forKey: userDefaultsKeyLastEndOfDayReminderDate)
        requestEndOfDayReminderNotification()
    }

    private func fetchToday(modelContext: ModelContext) -> PlanDay? {
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        var descriptor = FetchDescriptor<PlanDay>(
            predicate: #Predicate<PlanDay> { day in
                day.date >= today && day.date < tomorrow
            }
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first
    }

    private func incompleteTopLevelTaskCount(planDay: PlanDay) -> Int {
        planDay.tasks.filter { $0.parent == nil && !$0.isCompleted && !$0.isArchived }.count
    }

    private func requestEndOfDayReminderNotification() {
        let content = UNMutableNotificationContent()
        content.title = "End of day"
        content.body = "You have incomplete tasks in Telos. Finish or roll them over tomorrow."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "telos.endOfDay-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
}

import UserNotifications
