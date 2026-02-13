import Foundation

/// Tracks which calendar days the app was "used" (meaningful action) and computes the current streak.
/// "Used" = view/edit plan, start/stop task, add note, quick-add task (and optionally open retrospective).
@Observable
final class StreakStore {
    private let calendar = Calendar.current
    private let userDefaultsKey = "telos.usedDayDates"
    private let maxStoredDays = 400

    /// Call when the user performs a meaningful action (view plan, start/stop task, add note, quick-add).
    func recordUsage() {
        let key = dateKey(for: calendar.startOfDay(for: Date()))
        let defaults = UserDefaults.standard
        var list = (defaults.stringArray(forKey: userDefaultsKey)) ?? []
        if !list.contains(key) {
            list.append(key)
            list.sort(by: >)
            if list.count > maxStoredDays {
                list = Array(list.prefix(maxStoredDays))
            }
            defaults.set(list, forKey: userDefaultsKey)
        }
    }

    /// Number of used days (from recorded usage) that fall in [start, end). start/end are typically start-of-day dates.
    func usedDaysCount(from start: Date, to end: Date) -> Int {
        let set = Set((UserDefaults.standard.stringArray(forKey: userDefaultsKey)) ?? [])
        var count = 0
        var current = calendar.startOfDay(for: start)
        while current < end {
            if set.contains(dateKey(for: current)) { count += 1 }
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
        return count
    }

    /// Consecutive days of usage ending on the most recent used day (today if used, else yesterday).
    var currentStreak: Int {
        let set = Set((UserDefaults.standard.stringArray(forKey: userDefaultsKey)) ?? [])
        let today = dateKey(for: calendar.startOfDay(for: Date()))
        let yesterday = dateKey(for: calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: Date()))!)
        let endDay: String
        if set.contains(today) {
            endDay = today
        } else if set.contains(yesterday) {
            endDay = yesterday
        } else {
            return 0
        }
        var count = 0
        var current = endDay
        while set.contains(current) {
            count += 1
            guard let d = parseKey(current) else { break }
            guard let prev = calendar.date(byAdding: .day, value: -1, to: d) else { break }
            current = dateKey(for: prev)
        }
        return count
    }

    private func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = calendar.timeZone
        return formatter.string(from: date)
    }

    private func parseKey(_ key: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = calendar.timeZone
        return formatter.date(from: key)
    }
}
