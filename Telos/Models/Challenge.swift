import Foundation
import SwiftData

/// A time-boxed challenge with a visible track and biweekly retrospectives.
@Model
final class Challenge {
    var title: String
    /// Total days (custom, typically 7–365).
    var totalDays: Int
    /// Start of the challenge (calendar day).
    var startDate: Date
    var createdAt: Date
    /// When true, past days can be marked as done after the fact. When false, only the current day can be marked. Nil = true (for backward compatibility).
    var allowMarkPastDays: Bool?

    @Relationship(deleteRule: .cascade, inverse: \ChallengeDayProgress.challenge)
    var dayProgress: [ChallengeDayProgress] = []

    @Relationship(deleteRule: .cascade, inverse: \ChallengeRetrospective.challenge)
    var retrospectives: [ChallengeRetrospective] = []

    init(title: String, totalDays: Int, startDate: Date, createdAt: Date = Date(), allowMarkPastDays: Bool = true) {
        self.title = title
        self.totalDays = min(max(totalDays, 1), 365)
        self.startDate = Calendar.current.startOfDay(for: startDate)
        self.createdAt = createdAt
        self.allowMarkPastDays = allowMarkPastDays
    }

    /// Resolves nil (legacy) as true.
    var allowsMarkingPastDays: Bool {
        allowMarkPastDays ?? true
    }

    /// 1-based day index for the given calendar date (nil if outside challenge range).
    func dayIndex(for date: Date) -> Int? {
        let cal = Calendar.current
        let start = cal.startOfDay(for: startDate)
        let d = cal.startOfDay(for: date)
        guard d >= start else { return nil }
        let days = cal.dateComponents([.day], from: start, to: d).day ?? 0
        let index = days + 1
        return index <= totalDays ? index : nil
    }

    /// Calendar date for a 1-based day index.
    func date(forDayIndex index: Int) -> Date? {
        guard index >= 1, index <= totalDays else { return nil }
        return Calendar.current.date(byAdding: .day, value: index - 1, to: startDate)
    }

    /// Number of biweekly periods (14 days each); last period may be shorter.
    var biweeklyPeriodCount: Int {
        (totalDays + 13) / 14
    }

    /// Day range for a 1-based period index (startDay...endDay inclusive).
    func biweeklyPeriodDayRange(periodIndex: Int) -> (start: Int, end: Int)? {
        guard periodIndex >= 1, periodIndex <= biweeklyPeriodCount else { return nil }
        let start = (periodIndex - 1) * 14 + 1
        let end = min(periodIndex * 14, totalDays)
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
