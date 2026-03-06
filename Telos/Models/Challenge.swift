import Foundation
import SwiftData

/// A time-boxed challenge with a visible track and configurable retrospectives (every 3, 7, or 14 days).
@Model
final class Challenge {
    var title: String
    /// Optional description of what the challenge is about. Nil for legacy challenges.
    var challengeDescription: String?
    /// Total days (custom, typically 7–365).
    var totalDays: Int
    /// Start of the challenge (calendar day).
    var startDate: Date
    var createdAt: Date
    /// When true, past days can be marked as done after the fact. When false, only the current day can be marked. Nil = true (for backward compatibility).
    var allowMarkPastDays: Bool?
    /// When true, only weekdays (Monday–Friday) count as challenge days; Saturday and Sunday are skipped. Nil = false (legacy).
    var excludeWeekends: Bool?
    /// Retrospective interval in days: 3, 7, or 14. Nil = 14 (legacy).
    var retrospectivePeriodDays: Int?

    @Relationship(deleteRule: .cascade, inverse: \ChallengeDayProgress.challenge)
    var dayProgress: [ChallengeDayProgress] = []

    @Relationship(deleteRule: .cascade, inverse: \ChallengeRetrospective.challenge)
    var retrospectives: [ChallengeRetrospective] = []

    private static let allowedRetrospectivePeriods = [3, 7, 14]

    init(title: String, challengeDescription: String? = nil, totalDays: Int, startDate: Date, createdAt: Date = Date(), allowMarkPastDays: Bool = true, excludeWeekends: Bool = false, retrospectivePeriodDays: Int = 14) {
        self.title = title
        self.challengeDescription = challengeDescription?.isEmpty == true ? nil : challengeDescription
        self.totalDays = min(max(totalDays, 1), 365)
        self.startDate = Calendar.current.startOfDay(for: startDate)
        self.createdAt = createdAt
        self.allowMarkPastDays = allowMarkPastDays
        self.excludeWeekends = excludeWeekends
        self.retrospectivePeriodDays = Self.allowedRetrospectivePeriods.contains(retrospectivePeriodDays) ? retrospectivePeriodDays : 14
    }

    /// Effective retrospective period in days (3, 7, or 14). Defaults to 14 for legacy challenges.
    var effectiveRetrospectivePeriodDays: Int {
        guard let p = retrospectivePeriodDays, Self.allowedRetrospectivePeriods.contains(p) else { return 14 }
        return p
    }

    /// Resolves nil (legacy) as true.
    var allowsMarkingPastDays: Bool {
        allowMarkPastDays ?? true
    }

    /// Resolves nil (legacy) as false.
    var excludesWeekends: Bool {
        excludeWeekends ?? false
    }

    /// 1-based day index for the given calendar date (nil if outside challenge range).
    func dayIndex(for date: Date) -> Int? {
        let cal = Calendar.current
        let start = cal.startOfDay(for: startDate)
        let d = cal.startOfDay(for: date)
        guard d >= start else { return nil }
        if excludesWeekends {
            guard !cal.isDateInWeekend(d) else { return nil }
            var weekdayCount = 0
            var current = start
            while current <= d {
                if !cal.isDateInWeekend(current) {
                    weekdayCount += 1
                    if current == d {
                        return weekdayCount <= totalDays ? weekdayCount : nil
                    }
                }
                current = cal.date(byAdding: .day, value: 1, to: current) ?? current
            }
            return nil
        }
        let days = cal.dateComponents([.day], from: start, to: d).day ?? 0
        let index = days + 1
        return index <= totalDays ? index : nil
    }

    /// Calendar date for a 1-based day index.
    func date(forDayIndex index: Int) -> Date? {
        guard index >= 1, index <= totalDays else { return nil }
        let cal = Calendar.current
        if excludesWeekends {
            var count = 0
            var current = startDate
            while count < index {
                if !cal.isDateInWeekend(current) {
                    count += 1
                    if count == index { return current }
                }
                current = cal.date(byAdding: .day, value: 1, to: current) ?? current
            }
            return nil
        }
        return cal.date(byAdding: .day, value: index - 1, to: startDate)
    }

    /// Number of retrospective periods; last period may be shorter.
    var biweeklyPeriodCount: Int {
        let period = effectiveRetrospectivePeriodDays
        return (totalDays + period - 1) / period
    }

    /// Day range for a 1-based period index (startDay...endDay inclusive).
    func biweeklyPeriodDayRange(periodIndex: Int) -> (start: Int, end: Int)? {
        guard periodIndex >= 1, periodIndex <= biweeklyPeriodCount else { return nil }
        let period = effectiveRetrospectivePeriodDays
        let start = (periodIndex - 1) * period + 1
        let end = min(periodIndex * period, totalDays)
        return (start, end)
    }

    /// Number of completed days that have been reached (date is today or in the past).
    func completedReachedCount(calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: Date())
        return dayProgress.filter { progress in
            guard progress.isCompleted, let date = date(forDayIndex: progress.dayIndex) else { return false }
            return calendar.startOfDay(for: date) <= today
        }.count
    }
}
