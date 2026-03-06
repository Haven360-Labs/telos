import Foundation
import SwiftData

/// Ensures the current calendar day exists and handles morning and end-of-day reminders.
@Observable
final class DayStore {
    private let calendar = Calendar.current
    private let userDefaultsKeyFirstLaunchToday = "telos.firstLaunchToday"
    private let userDefaultsKeyLastEndOfDayReminderDate = "telos.lastEndOfDayReminderDate"
    private let userDefaultsKeyEndOfDayReminderHour = "telos.endOfDayReminderHour"
    private let userDefaultsKeyEndOfDayReminderMinute = "telos.endOfDayReminderMinute"
    private let defaultEndOfDayHour = 18
    private let defaultEndOfDayMinute = 0

    /// Creates or fetches the plan day for the given date. Call at launch and when day changes.
    /// New days are created empty; use "Copy from past day" to bring over incomplete tasks (copies have time reset to 0; originals stay for audit).
    func ensureTodayExists(modelContext: ModelContext) {
        let today = calendar.startOfDay(for: Date())
        _ = ensureDayExists(for: today, modelContext: modelContext)
    }

    /// Fetches the plan day for the given calendar date, or nil if none exists.
    func fetchDay(for date: Date, modelContext: ModelContext) -> PlanDay? {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        var descriptor = FetchDescriptor<PlanDay>(
            predicate: #Predicate<PlanDay> { day in
                day.date >= start && day.date < end
            }
        )
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first
    }

    /// Ensures a plan day exists for the given date; creates it empty if missing.
    func ensureDayExists(for date: Date, modelContext: ModelContext) -> PlanDay {
        let start = calendar.startOfDay(for: date)
        if let existing = fetchDay(for: start, modelContext: modelContext) {
            return existing
        }
        let planDay = PlanDay(date: start, createdAt: Date())
        modelContext.insert(planDay)
        try? modelContext.save()
        return planDay
    }

    /// Copies incomplete top-level tasks (and their subtasks) from a past day to the target day.
    /// Copies have time reset to 0 for accurate new-day logging; originals stay on the past day for time audit.
    /// Returns the number of top-level tasks copied.
    private func copyIncompleteTasks(from pastDayStart: Date, to targetDay: PlanDay, modelContext: ModelContext) -> Int {
        let pastDayEnd = calendar.date(byAdding: .day, value: 1, to: pastDayStart)!
        var descriptor = FetchDescriptor<PlanDay>(
            predicate: #Predicate<PlanDay> { day in
                day.date >= pastDayStart && day.date < pastDayEnd
            }
        )
        descriptor.fetchLimit = 1
        guard let pastPlan = (try? modelContext.fetch(descriptor))?.first else { return 0 }
        let incompleteTopLevel = pastPlan.tasks.filter { $0.parent == nil && !$0.isCompleted && !$0.isArchived }
        let baseSortOrder = (targetDay.tasks.filter { $0.parent == nil }.map(\.sortOrder).max() ?? -1) + 1
        for (index, sourceTask) in incompleteTopLevel.enumerated() {
            let newTask = PlanTask(
                title: sourceTask.title,
                isCompleted: false,
                createdAt: Date(),
                sortOrder: baseSortOrder + index,
                planDay: targetDay,
                parent: nil,
                quadrant: sourceTask.quadrant,
                scheduledDate: sourceTask.scheduledDate
            )
            newTask.isRolledOver = true
            newTask.timeSpentSeconds = 0
            modelContext.insert(newTask)
            targetDay.tasks.append(newTask)
            for (subIndex, sourceSub) in sourceTask.subtasks.sorted(by: { $0.sortOrder < $1.sortOrder }).enumerated() {
                let newSub = PlanTask(
                    title: sourceSub.title,
                    isCompleted: sourceSub.isCompleted,
                    createdAt: Date(),
                    sortOrder: subIndex,
                    planDay: targetDay,
                    parent: newTask,
                    quadrant: sourceSub.quadrant,
                    scheduledDate: sourceSub.scheduledDate
                )
                newSub.isRolledOver = true
                newSub.timeSpentSeconds = 0
                modelContext.insert(newSub)
                newTask.subtasks.append(newSub)
            }
        }
        try? modelContext.save()
        return incompleteTopLevel.count
    }

    /// Copies all incomplete tasks and subtasks from a past day to the target day (time reset to 0 on copies; originals unchanged for audit).
    /// Target day is created if needed. Returns the number of top-level tasks copied.
    func moveIncompleteTasks(from pastDayStart: Date, to targetDay: PlanDay, modelContext: ModelContext) -> Int {
        let startOfPast = calendar.startOfDay(for: pastDayStart)
        guard startOfPast != calendar.startOfDay(for: targetDay.date) else { return 0 }
        return copyIncompleteTasks(from: startOfPast, to: targetDay, modelContext: modelContext)
    }

    /// Copies all incomplete tasks and subtasks from a past day to today (time reset to 0; originals stay for audit). Ensures today exists first.
    /// Returns the number of top-level tasks copied.
    func moveIncompleteTasksFromPastDayToToday(pastDayStart: Date, modelContext: ModelContext) -> Int {
        ensureTodayExists(modelContext: modelContext)
        guard let todayPlan = fetchToday(modelContext: modelContext) else { return 0 }
        return moveIncompleteTasks(from: pastDayStart, to: todayPlan, modelContext: modelContext)
    }

    /// Fixed identifier for the scheduled morning notification so we can replace or remove it.
    private static let morningScheduledIdentifier = "telos.morning.scheduled"

    /// Call when app becomes active: keep the scheduled morning reminder in sync with settings.
    func scheduleMorningReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.morningScheduledIdentifier])
        guard AppNotificationSettings.morningReminderEnabled else { return }
        let hour = AppNotificationSettings.morningReminderHour
        let minute = AppNotificationSettings.morningReminderMinute
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let content = UNMutableNotificationContent()
        content.title = "Good morning"
        content.body = "Review your day plan in Telos."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: Self.morningScheduledIdentifier,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// Call when app becomes active or on appear: show at most one end-of-day reminder per day
    /// if current time is at or past the configured end-of-day time and today has incomplete tasks.
    func showEndOfDayReminderIfNeeded(modelContext: ModelContext) {
        guard AppNotificationSettings.endOfDayReminderEnabled else { return }
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
