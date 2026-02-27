import AppKit
import SwiftUI
import SwiftData

/// AppKit status bar item so we can set the button title (timer + task) and have it actually show in the menu bar.
@MainActor
final class StatusBarController: NSObject {
    static let openMainWindowNotification = Notification.Name("TelosStatusBarOpenMainWindow")

    private static var shared: StatusBarController?
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private weak var timerStore: TimerStore?
    private weak var dayStore: DayStore?
    private weak var streakStore: StreakStore?
    private var modelContainer: ModelContainer?
    private var updateTimer: Timer?

    static func install(
        timerStore: TimerStore,
        dayStore: DayStore,
        streakStore: StreakStore,
        modelContainer: ModelContainer
    ) {
        if shared != nil { return }
        let controller = StatusBarController()
        controller.timerStore = timerStore
        controller.dayStore = dayStore
        controller.streakStore = streakStore
        controller.modelContainer = modelContainer
        controller.setupStatusItem()
        controller.startLabelTimer()
        controller.observeOpenMainWindow()
        shared = controller
    }

    private func observeOpenMainWindow() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(closePopoverAndActivate),
            name: Self.openMainWindowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(menuBarLabelLengthDidChange),
            name: AppMenuBarSettings.menuBarLabelLengthDidChangeNotification,
            object: nil
        )
    }

    @objc private func menuBarLabelLengthDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.updateButtonLabel()
        }
    }

    @objc private func closePopoverAndActivate() {
        popover?.performClose(nil)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        button.target = self
        button.action = #selector(togglePopover)
        updateButtonLabel()
        popover = NSPopover()
        popover?.behavior = .transient
        popover?.contentSize = NSSize(width: 280, height: 400)
    }

    private func updateButtonLabel() {
        guard let button = statusItem?.button, let timerStore = timerStore else { return }
        let (title, iconName) = currentLabelAndIcon()
        button.title = title
        button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
        button.imagePosition = .imageLeading
    }

    private func currentLabelAndIcon() -> (String, String) {
        guard let timerStore = timerStore else { return ("Telos", "sun.max.fill") }
        let useShort = AppMenuBarSettings.labelLength == .short
        let totalToday = formattedTotalTimeToday()
        if timerStore.activeTaskID == nil {
            if useShort {
                return ("Telos", "sun.max.fill")
            }
            return ("Telos · \(totalToday)", "sun.max.fill")
        }
        let time: String
        if timerStore.isCountUp {
            _ = timerStore.countUpTick
            time = timerStore.formattedElapsed
        } else {
            time = timerStore.formattedRemaining
        }
        let task = timerStore.activeTaskTitle ?? "Task"
        let maxTaskLen = useShort ? 20 : 100
        let truncatedTask = task.count > maxTaskLen ? String(task.prefix(maxTaskLen - 1)) + "…" : task
        if useShort {
            let pausedSuffix = timerStore.isPaused ? " ⏸" : ""
            return ("\(time) · \(truncatedTask)\(pausedSuffix)", "timer")
        }
        let pausedSuffix = timerStore.isPaused ? " (paused)" : ""
        return ("\(time) · \(truncatedTask)\(pausedSuffix) · Total: \(totalToday)", "timer")
    }

    /// Total time logged today (from tasks + current count-up if active task is today). Returns formatted string e.g. "2h 30m" or "45m" or "0m".
    private func formattedTotalTimeToday() -> String {
        guard let container = modelContainer else { return "0m" }
        let context = container.mainContext
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart)!
        var descriptor = FetchDescriptor<PlanDay>(
            predicate: #Predicate<PlanDay> { day in
                day.date >= todayStart && day.date < tomorrowStart
            }
        )
        descriptor.fetchLimit = 1
        guard let planDay = try? context.fetch(descriptor).first else { return "0m" }
        var totalSeconds = planDay.tasks.reduce(0.0) { $0 + $1.timeSpentSeconds }
        if timerStore?.isCountUp == true, let activeID = timerStore?.activeTaskID,
           let task = try? context.model(for: activeID) as? PlanTask,
           let day = task.planDay, calendar.isDate(day.date, inSameDayAs: Date()) {
            totalSeconds += timerStore?.countUpElapsedSeconds ?? 0
        }
        let total = Int(totalSeconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 {
            return "\(h)h \(m)m"
        }
        return "\(m)m"
    }

    private func startLabelTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.updateButtonLabel() }
        }
        RunLoop.main.add(updateTimer!, forMode: .common)
    }

    @objc private func togglePopover() {
        guard let button = statusItem?.button, let popover = popover else { return }
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        guard let dayStore = dayStore, let timerStore = timerStore, let streakStore = streakStore, let modelContainer = modelContainer else { return }
        let content = MenuBarPopoverContent(
            dayStore: dayStore,
            timerStore: timerStore,
            streakStore: streakStore,
            modelContainer: modelContainer
        )
        popover.contentViewController = NSHostingController(rootView: content)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
}

/// SwiftUI view for the status bar popover so we can inject environment and model container.
private struct MenuBarPopoverContent: View {
    let dayStore: DayStore
    let timerStore: TimerStore
    let streakStore: StreakStore
    let modelContainer: ModelContainer

    var body: some View {
        MenuBarView()
            .environment(dayStore)
            .environment(timerStore)
            .environment(streakStore)
            .modelContainer(modelContainer)
    }
}
