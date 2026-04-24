import Foundation

/// Application Support layout for Telos SwiftData and backups.
enum TelosStoreLocation {
    static let appSupportSubdirectory = "com.telos.app"
    static let storeFileName = "Telos.store"
    static let backupsFolderName = "Backups"
    static let snapshotFileName = "snapshot.json"
    static let legacyMigrationDefaultsKey = "telos.migratedLegacyDefaultStore"

    static var applicationSupportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    }

    /// `~/Library/Application Support/com.telos.app/`
    static var telosDirectory: URL {
        applicationSupportDirectory.appendingPathComponent(appSupportSubdirectory, isDirectory: true)
    }

    /// Primary SwiftData store URL.
    static var storeURL: URL {
        telosDirectory.appendingPathComponent(storeFileName, isDirectory: false)
    }

    /// Automatic backup artifacts (timestamped subfolders).
    static var backupsDirectory: URL {
        telosDirectory.appendingPathComponent(backupsFolderName, isDirectory: true)
    }

    /// Legacy generic store used before dedicated path (may belong to any SwiftData app using defaults).
    static var legacyDefaultStoreURL: URL {
        applicationSupportDirectory.appendingPathComponent("default.store", isDirectory: false)
    }

    /// Ensures `com.telos.app` exists and copies legacy `default.store` once if `Telos.store` is missing.
    static func prepareStoreDirectoryAndMigrateLegacyIfNeeded() {
        let fm = FileManager.default
        try? fm.createDirectory(at: telosDirectory, withIntermediateDirectories: true)

        guard !fm.fileExists(atPath: storeURL.path) else { return }
        guard fm.fileExists(atPath: legacyDefaultStoreURL.path) else { return }
        guard !UserDefaults.standard.bool(forKey: legacyMigrationDefaultsKey) else { return }

        let legacyWAL = applicationSupportDirectory.appendingPathComponent("default.store-wal", isDirectory: false)
        let legacySHM = applicationSupportDirectory.appendingPathComponent("default.store-shm", isDirectory: false)
        let destWAL = telosDirectory.appendingPathComponent("Telos.store-wal", isDirectory: false)
        let destSHM = telosDirectory.appendingPathComponent("Telos.store-shm", isDirectory: false)

        do {
            try fm.copyItem(at: legacyDefaultStoreURL, to: storeURL)
            if fm.fileExists(atPath: legacyWAL.path) {
                try? fm.copyItem(at: legacyWAL, to: destWAL)
            }
            if fm.fileExists(atPath: legacySHM.path) {
                try? fm.copyItem(at: legacySHM, to: destSHM)
            }
            UserDefaults.standard.set(true, forKey: legacyMigrationDefaultsKey)
        } catch {
            try? fm.removeItem(at: storeURL)
            try? fm.removeItem(at: destWAL)
            try? fm.removeItem(at: destSHM)
        }
    }
}
