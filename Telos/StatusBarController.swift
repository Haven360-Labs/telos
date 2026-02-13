import AppKit
import SwiftUI
import SwiftData

/// AppKit status bar item so we can set the button title (timer + task) and have it actually show in the menu bar.
final class StatusBarController: NSObject {
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
        shared = controller
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
        if timerStore.activeTaskID == nil {
            return ("Telos", "sun.max.fill")
        }
        let time: String
        if timerStore.isCountUp {
            _ = timerStore.countUpTick
            time = timerStore.formattedElapsed
        } else {
            time = timerStore.formattedRemaining
        }
        let task = timerStore.activeTaskTitle ?? "Task"
        let short = task.count > 16 ? String(task.prefix(15)) + "…" : task
        let pausedSuffix = timerStore.isPaused ? " (paused)" : ""
        return ("\(time) · \(short)\(pausedSuffix)", "timer")
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
