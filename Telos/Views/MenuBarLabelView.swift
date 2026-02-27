import SwiftUI

/// Dynamic menu bar label: shows count-up/countdown time (and optional task) directly in the bar when a timer is active.
struct MenuBarLabelView: View {
    var timerStore: TimerStore

    var body: some View {
        if timerStore.activeTaskID != nil {
            Label(
                "\(menuBarTimeText) · \(compactTitle(timerStore.activeTaskTitle ?? "Task"))",
                systemImage: "timer"
            )
            .monospacedDigit()
            .lineLimit(1)
        } else {
            Label("Telos", systemImage: "sun.max.fill")
        }
    }

    /// Subscribes to countUpTick so label updates every second when count-up is running.
    private var menuBarTimeText: String {
        if timerStore.isCountUp {
            _ = timerStore.countUpTick
            return timerStore.formattedElapsed
        }
        return timerStore.formattedRemaining
    }

    private func compactTitle(_ title: String) -> String {
        let maxLen = 100
        if title.count <= maxLen { return title }
        return String(title.prefix(maxLen - 1)) + "…"
    }
}
