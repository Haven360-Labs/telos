import Foundation
import SwiftData
import SwiftUI
import AppKit

/// Automatic and manual backups: copies `Telos.store` (+ WAL/SHM) and `snapshot.json`, keeps 7 rotations locally and mirrors to iCloud when available.
@MainActor
final class TelosBackupCoordinator: ObservableObject {
    static let shared = TelosBackupCoordinator()

    /// Minimum interval between automatic backups (manual "Backup now" bypasses).
    private let throttleInterval: TimeInterval = 10 * 60
    private let maxBackups = 7
    private let defaultsThrottleKey = "telos.backup.lastAutoBackupAt"
    private let defaultsFingerprintKey = "telos.backup.lastStoreFingerprint"

    private init() {}

    /// Fingerprint for change detection: size + mod date (seconds).
    private func storeFingerprint() -> String? {
        let url = TelosStoreLocation.storeURL
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else { return nil }
        let size = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        let mod = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        return "\(size)_\(mod)"
    }

    /// Called after app launch once the model container exists.
    func scheduleLaunchBackup(modelContext: ModelContext) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.performAutomaticBackupIfNeeded(modelContext: modelContext, force: false)
        }
    }

    /// After save / background / terminate.
    func scheduleBackupAfterPersistence(modelContext: ModelContext) {
        performAutomaticBackupIfNeeded(modelContext: modelContext, force: false)
    }

    /// Call from a periodic timer in the main UI (e.g. every 15 minutes) with the live `ModelContext`.
    func tickPeriodicBackup(modelContext: ModelContext) {
        performAutomaticBackupIfNeeded(modelContext: modelContext, force: false)
    }

    /// User-triggered; bypasses throttle (still rotates to max 7).
    func backupNow(modelContext: ModelContext) throws {
        try createBackupArtifact(modelContext: modelContext)
        try copyLatestToICloudIfAvailable()
        UserDefaults.standard.set(Date(), forKey: defaultsThrottleKey)
        if let fp = storeFingerprint() {
            UserDefaults.standard.set(fp, forKey: defaultsFingerprintKey)
        }
    }

    private func performAutomaticBackupIfNeeded(modelContext: ModelContext, force: Bool) {
        let now = Date()
        if !force {
            if let last = UserDefaults.standard.object(forKey: defaultsThrottleKey) as? Date,
               now.timeIntervalSince(last) < throttleInterval {
                return
            }
        }

        let fp = storeFingerprint()
        if !force, let fp, fp == UserDefaults.standard.string(forKey: defaultsFingerprintKey) {
            return
        }

        do {
            try createBackupArtifact(modelContext: modelContext)
            UserDefaults.standard.set(now, forKey: defaultsThrottleKey)
            if let fp { UserDefaults.standard.set(fp, forKey: defaultsFingerprintKey) }
            try copyLatestToICloudIfAvailable()
        } catch {
            #if DEBUG
            print("Telos backup failed: \(error)")
            #endif
        }
    }

    private func createBackupArtifact(modelContext: ModelContext) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: TelosStoreLocation.backupsDirectory, withIntermediateDirectories: true)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var stamp = formatter.string(from: Date())
        stamp = stamp.replacingOccurrences(of: ":", with: "-")
        let folder = TelosStoreLocation.backupsDirectory.appendingPathComponent(stamp, isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)

        let jsonData = try TelosFullBackup.exportSnapshotJSON(modelContext: modelContext)
        let jsonURL = folder.appendingPathComponent(TelosStoreLocation.snapshotFileName)
        try jsonData.write(to: jsonURL, options: .atomic)

        let base = TelosStoreLocation.storeURL
        let triple: [(String, String)] = [
            (base.path, "Telos.store"),
            (base.path + "-wal", "Telos.store-wal"),
            (base.path + "-shm", "Telos.store-shm"),
        ]
        for (srcPath, name) in triple {
            let src = URL(fileURLWithPath: srcPath)
            guard fm.fileExists(atPath: src.path) else { continue }
            let dst = folder.appendingPathComponent(name)
            if fm.fileExists(atPath: dst.path) { try? fm.removeItem(at: dst) }
            try fm.copyItem(at: src, to: dst)
        }

        try pruneOldBackups()
    }

    private func pruneOldBackups() throws {
        let fm = FileManager.default
        let root = TelosStoreLocation.backupsDirectory
        let urls = try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey], options: [.skipsHiddenFiles])
        let dirs = urls.filter {
            (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        }
        let sorted = dirs.sorted { a, b in
            let da = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return da > db
        }
        if sorted.count > maxBackups {
            for u in sorted.dropFirst(maxBackups) {
                try? fm.removeItem(at: u)
            }
        }
    }

    /// Sorted newest first, at most `maxBackups` folders after prune.
    func listLocalBackupFolders() -> [URL] {
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(at: TelosStoreLocation.backupsDirectory, includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey], options: [.skipsHiddenFiles]) else {
            return []
        }
        let dirs = urls.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        return dirs.sorted { a, b in
            let da = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return da > db
        }
    }

    /// Nil when iCloud is unavailable (e.g. Personal Team builds: iCloud capability requires Apple Developer Program).
    func iCloudBackupsRoot() -> URL? {
        guard let base = FileManager.default.url(forUbiquityContainerIdentifier: nil) else { return nil }
        return base.appendingPathComponent("Documents/TelosBackups", isDirectory: true)
    }

    func listICloudBackupFolders() -> [URL] {
        guard let root = iCloudBackupsRoot() else { return [] }
        let fm = FileManager.default
        guard let urls = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey], options: [.skipsHiddenFiles]) else {
            return []
        }
        let dirs = urls.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        return dirs.sorted { a, b in
            let da = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return da > db
        }
    }

    private func copyLatestToICloudIfAvailable() throws {
        guard let iCloudRoot = iCloudBackupsRoot() else { return }
        let fm = FileManager.default
        try fm.createDirectory(at: iCloudRoot, withIntermediateDirectories: true)
        let locals = listLocalBackupFolders()
        guard let newest = locals.first else { return }
        let destFolder = iCloudRoot.appendingPathComponent(newest.lastPathComponent, isDirectory: true)
        if fm.fileExists(atPath: destFolder.path) {
            try fm.removeItem(at: destFolder)
        }
        try fm.copyItem(at: newest, to: destFolder)
        try pruneICloudBackups(root: iCloudRoot)
    }

    private func pruneICloudBackups(root: URL) throws {
        let fm = FileManager.default
        let urls = try fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey, .creationDateKey], options: [.skipsHiddenFiles])
        let dirs = urls.filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        let sorted = dirs.sorted { a, b in
            let da = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let db = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return da > db
        }
        if sorted.count > maxBackups {
            for u in sorted.dropFirst(maxBackups) {
                try? fm.removeItem(at: u)
            }
        }
    }

    func openLocalBackupsFolder() {
        NSWorkspace.shared.open(TelosStoreLocation.backupsDirectory)
    }

    static func readSnapshotExportedAt(folder: URL) -> Date? {
        let url = folder.appendingPathComponent(TelosStoreLocation.snapshotFileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        struct Partial: Decodable { let exportedAt: Date }
        return (try? decoder.decode(Partial.self, from: data))?.exportedAt
    }

    static func folderByteSize(_ folder: URL) -> Int64 {
        let fm = FileManager.default
        guard let en = fm.enumerator(at: folder, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let u as URL in en {
            let v = try? u.resourceValues(forKeys: [.fileSizeKey])
            total += Int64(v?.fileSize ?? 0)
        }
        return total
    }
}
