import Foundation
import SwiftData
import AppKit

/// Manages the single active task and its timer (countdown or count-up). Only one task (or subtask) can be active at a time.
@Observable
final class TimerStore {
    var activeTaskID: PersistentIdentifier?
    var countdownTotalSeconds: TimeInterval = 0
    var countdownRemainingSeconds: TimeInterval = 0
    /// For count-up mode: when the timer started. Elapsed = now - countUpStartDate.
    var countUpStartDate: Date?
    var isRunning: Bool = false
    /// When true, timer is count-up (elapsed); when false, countdown (remaining).
    var isCountUp: Bool = false
    /// Incremented every second in count-up mode so UI refreshes elapsed display.
    var countUpTick: Int = 0
    /// When true, timer is paused (no tick); remaining/elapsed stay fixed until resume.
    var isPaused: Bool = false
    /// When paused in count-up mode, holds elapsed seconds so we can resume from the same value.
    private var countUpPausedElapsedSeconds: TimeInterval = 0

    private var timer: Timer?
    private let calendar = Calendar.current

    /// Display title for the active task (e.g. "Task name" or "Parent → Subtask").
    var activeTaskTitle: String? {
        guard activeTaskID != nil else { return nil }
        return _activeTaskTitle
    }
    private var _activeTaskTitle: String?

    func setActiveTaskTitle(_ title: String?) {
        _activeTaskTitle = title
    }

    /// Start counting down for a task. Only one task can be active; starting another replaces the current.
    func startCountdown(task: PlanTask, durationMinutes: Int, modelContext: ModelContext) {
        stopAndRecord(modelContext: modelContext)
        activeTaskID = task.persistentModelID
        _activeTaskTitle = task.parent != nil ? "\(task.parent!.title) → \(task.title)" : task.title
        countdownTotalSeconds = TimeInterval(durationMinutes * 60)
        countdownRemainingSeconds = countdownTotalSeconds
        countUpStartDate = nil
        isCountUp = false
        isRunning = true
        isPaused = false
        countUpPausedElapsedSeconds = 0
        scheduleTick(modelContext: modelContext)
    }

    /// Start count-up timer for a task (no fixed duration; time accumulates until stopped).
    func startCountUp(task: PlanTask, modelContext: ModelContext) {
        stopAndRecord(modelContext: modelContext)
        activeTaskID = task.persistentModelID
        _activeTaskTitle = task.parent != nil ? "\(task.parent!.title) → \(task.title)" : task.title
        countUpStartDate = Date()
        countdownTotalSeconds = 0
        countdownRemainingSeconds = 0
        isCountUp = true
        isRunning = true
        isPaused = false
        countUpPausedElapsedSeconds = 0
        scheduleTick(modelContext: modelContext)
    }

    /// Pause the active timer (count-up or countdown). Remaining/elapsed stay fixed until resume.
    func pause() {
        guard activeTaskID != nil, isRunning, !isPaused else { return }
        timer?.invalidate()
        timer = nil
        if isCountUp {
            countUpPausedElapsedSeconds = countUpElapsedSeconds
        }
        isPaused = true
    }

    /// Resume a paused timer.
    func resume(modelContext: ModelContext) {
        guard activeTaskID != nil, isRunning, isPaused else { return }
        if isCountUp {
            countUpStartDate = Date().addingTimeInterval(-countUpPausedElapsedSeconds)
        }
        isPaused = false
        countUpPausedElapsedSeconds = 0
        scheduleTick(modelContext: modelContext)
    }

    func stopAndRecord(modelContext: ModelContext) {
        timer?.invalidate()
        timer = nil
        guard let id = activeTaskID else {
            isRunning = false
            isCountUp = false
            countUpStartDate = nil
            return
        }
        if isRunning {
            let elapsed: TimeInterval
            if isCountUp {
                elapsed = isPaused ? countUpPausedElapsedSeconds : (countUpStartDate.map { Date().timeIntervalSince($0) } ?? 0)
            } else if countdownTotalSeconds > 0, countdownRemainingSeconds < countdownTotalSeconds {
                elapsed = countdownTotalSeconds - countdownRemainingSeconds
            } else {
                elapsed = 0
            }
            if elapsed > 0, let task = modelContext.model(for: id) as? PlanTask {
                task.timeSpentSeconds += elapsed
                try? modelContext.save()
            }
        }
        activeTaskID = nil
        _activeTaskTitle = nil
        countdownTotalSeconds = 0
        countdownRemainingSeconds = 0
        countUpStartDate = nil
        isCountUp = false
        countUpTick = 0
        isPaused = false
        countUpPausedElapsedSeconds = 0
        isRunning = false
    }

    private func playCountdownFinishedSound() {
        DispatchQueue.main.async {
            let name = UserDefaults.standard.string(forKey: AppSoundSettings.countdownSoundKey)
            if let name = name, !name.isEmpty, name != "None" {
                if let sound = NSSound(named: name) {
                    sound.play()
                    return
                }
            }
            if let sound = NSSound(named: AppSoundSettings.defaultSoundName) {
                sound.play()
            } else {
                NSSound.beep()
            }
        }
    }

    private func scheduleTick(modelContext: ModelContext) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick(modelContext: modelContext)
        }
        timer?.tolerance = 0.2
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func tick(modelContext: ModelContext) {
        guard !isPaused else { return }
        if isCountUp {
            countUpTick += 1
            return
        }
        guard isRunning, countdownRemainingSeconds > 0 else { return }
        countdownRemainingSeconds -= 1
        if countdownRemainingSeconds <= 0 {
            // Countdown finished: play alert, record duration, then switch to count-up for same task
            playCountdownFinishedSound()
            if let id = activeTaskID,
               let task = modelContext.model(for: id) as? PlanTask {
                task.timeSpentSeconds += countdownTotalSeconds
                try? modelContext.save()
                // Keep same task active; switch to count-up so user can continue until they mark complete
                countUpStartDate = Date()
                countdownTotalSeconds = 0
                countdownRemainingSeconds = 0
                isCountUp = true
                countUpTick = 0
            } else {
                timer?.invalidate()
                timer = nil
                activeTaskID = nil
                _activeTaskTitle = nil
                isRunning = false
            }
        }
    }

    func isActive(task: PlanTask) -> Bool {
        guard let id = activeTaskID else { return false }
        return task.persistentModelID == id
    }

    /// Formatted time remaining for countdown (hh:mm:ss when >= 1 hour, else mm:ss).
    var formattedRemaining: String {
        let total = Int(countdownRemainingSeconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    /// Elapsed seconds for count-up (from countUpStartDate to now, or paused value when paused).
    var countUpElapsedSeconds: TimeInterval {
        guard isCountUp else { return 0 }
        if isPaused { return countUpPausedElapsedSeconds }
        guard let start = countUpStartDate else { return 0 }
        return Date().timeIntervalSince(start)
    }

    /// Formatted elapsed for count-up (hh:mm:ss when >= 1 hour, else mm:ss).
    var formattedElapsed: String {
        let total = Int(countUpElapsedSeconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    /// Display string for the active timer bar: remaining (countdown) or elapsed (count-up).
    var activeTimerDisplay: String {
        isCountUp ? formattedElapsed : formattedRemaining
    }
}
