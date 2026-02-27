import Foundation
import SwiftData
import AppKit

/// Exports plans, tasks, and notes to CSV files. v1 scope: all data (no date filter).
enum ExportService {

    /// Present a directory picker and write `telos_tasks.csv` and `telos_notes.csv` there.
    /// Exports all plans, tasks, and notes. Call from main thread.
    static func exportToCSV(modelContext: ModelContext) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Export Here"
        panel.message = "Choose a folder. Telos will create telos_tasks.csv and telos_notes.csv with all plans, tasks, and notes."
        panel.runModal()

        guard let url = panel.url else { return }

        let tasksCSV = buildTasksCSV(modelContext: modelContext)
        let notesCSV = buildNotesCSV(modelContext: modelContext)

        let tasksURL = url.appendingPathComponent("telos_tasks.csv", isDirectory: false)
        let notesURL = url.appendingPathComponent("telos_notes.csv", isDirectory: false)

        do {
            try tasksCSV.write(to: tasksURL, atomically: true, encoding: .utf8)
            try notesCSV.write(to: notesURL, atomically: true, encoding: .utf8)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Export failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.runModal()
            return
        }

        let alert = NSAlert()
        alert.messageText = "Export complete"
        alert.informativeText = "Saved to \(url.path)"
        alert.alertStyle = .informational
        alert.runModal()
    }

    private static func buildTasksCSV(modelContext: ModelContext) -> String {
        var descriptor = FetchDescriptor<PlanDay>(sortBy: [SortDescriptor(\.date, order: .forward)])
        let days = (try? modelContext.fetch(descriptor)) ?? []
        var rows: [String] = []
        let header = "plan_date,task_title,parent_title,quadrant,is_completed,time_spent_seconds,is_archived,is_rolled_over,created_at"
        rows.append(header)
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        for day in days {
            let planDate = dateFormatter.string(from: day.date)
            let topLevel = day.tasks.filter { $0.parent == nil }.sorted { $0.sortOrder < $1.sortOrder }
            for task in topLevel {
                rows.append(taskRow(task: task, planDate: planDate, parentTitle: ""))
                for sub in task.sortedSubtasks {
                    rows.append(taskRow(task: sub, planDate: planDate, parentTitle: escapeCSV(task.title)))
                }
            }
        }
        return rows.joined(separator: "\n")
    }

    private static func taskRow(task: PlanTask, planDate: String, parentTitle: String) -> String {
        let iso = ISO8601DateFormatter()
        let created = iso.string(from: task.createdAt)
        let quadrantLabel = task.quadrant.shortTitle
        return [
            planDate,
            escapeCSV(task.title),
            parentTitle,
            escapeCSV(quadrantLabel),
            task.isCompleted ? "1" : "0",
            String(Int(task.timeSpentSeconds)),
            task.isArchived ? "1" : "0",
            task.isRolledOver ? "1" : "0",
            created,
        ].joined(separator: ",")
    }

    private static func buildNotesCSV(modelContext: ModelContext) -> String {
        var descriptor = FetchDescriptor<PlanNote>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        let notes = (try? modelContext.fetch(descriptor)) ?? []
        var rows: [String] = []
        rows.append("created_at,title,content,plan_date")
        let iso = ISO8601DateFormatter()
        let dateOnly = ISO8601DateFormatter()
        dateOnly.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        for note in notes {
            let created = iso.string(from: note.createdAt)
            let planDate = note.planDay.map { dateOnly.string(from: $0.date) } ?? ""
            rows.append([created, escapeCSV(note.title), escapeCSV(note.content), planDate].joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }

    private static func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\n") || value.contains("\"") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }
}
