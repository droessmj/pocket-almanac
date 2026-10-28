// Copyright (c) 2026 Michael Droessler
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

import Foundation
import OSLog
import Security

/// Message metadata only. Older entries' obsolete keychainStatus field is ignored when decoding.
struct ActivityEntry: Codable, Identifiable {
    enum Verdict: String, Codable { case spam, allowed }

    var id = UUID()
    var received: Date
    var sender: String
    var verdict: Verdict
    var reason: String
}

struct StoredActivityItem {
    let account: String
    let data: Data?
}

protocol ActivityLogStorage {
    func items() throws -> [StoredActivityItem]
    func add(_ entry: ActivityEntry) throws
    func delete(account: String) throws
    func deleteAll() throws
}

enum ActivityLogError: Error {
    case missingAccessGroup
    case invalidResult
    case keychain(OSStatus)
}

struct KeychainActivityStorage: ActivityLogStorage {
    let accessGroup: String?

    private func baseQuery() throws -> [CFString: Any] {
        // Never silently fall back to a private keychain when shared signing is misconfigured.
        guard let accessGroup, !accessGroup.isEmpty, !accessGroup.contains("$(") else {
            throw ActivityLogError.missingAccessGroup
        }
        return [kSecClass: kSecClassGenericPassword,
                kSecAttrService: "com.droessmj.sift.activity",
                kSecAttrAccessGroup: accessGroup,
                kSecAttrSynchronizable: false]
    }

    func items() throws -> [StoredActivityItem] {
        var query = try baseQuery()
        query[kSecMatchLimit] = kSecMatchLimitAll
        query[kSecReturnAttributes] = true
        query[kSecReturnData] = true
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess else { throw ActivityLogError.keychain(status) }
        guard let items = result as? [[CFString: Any]] else { throw ActivityLogError.invalidResult }
        return try items.map { item in
            guard let account = item[kSecAttrAccount] as? String else { throw ActivityLogError.invalidResult }
            return StoredActivityItem(account: account, data: item[kSecValueData] as? Data)
        }
    }

    func add(_ entry: ActivityEntry) throws {
        var item = try baseQuery()
        item[kSecAttrAccount] = entry.id.uuidString
        item[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        item[kSecValueData] = try JSONEncoder().encode(entry)
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw ActivityLogError.keychain(status) }
    }

    func delete(account: String) throws {
        var query = try baseQuery()
        query[kSecAttrAccount] = account
        try checkDeletion(SecItemDelete(query as CFDictionary))
    }

    func deleteAll() throws {
        let query = try baseQuery()
        try checkDeletion(SecItemDelete(query as CFDictionary))
    }

    private func checkDeletion(_ status: OSStatus) throws {
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ActivityLogError.keychain(status)
        }
    }
}

/// Separate keychain items prevent app/extension writes from replacing the whole history.
/// Operations in one process are serialized. Cross-process pruning deletes only items it read;
/// concurrent app/extension operations converge to the limit at the next read or write.
final class ActivityLogStore {
    static let retentionDays = 30
    static let maxEntries = 1000

    private let storage: any ActivityLogStorage
    private let legacyFileURL: URL?
    private let lock = NSLock()

    init(storage: any ActivityLogStorage, legacyFileURL: URL?) {
        self.storage = storage
        self.legacyFileURL = legacyFileURL
    }

    func record(_ entry: ActivityEntry, now: Date = Date()) throws {
        try lock.withLock {
            // Failed reads/pruning must not allow repeated writes to grow inaccessible storage.
            _ = try loadUnlocked(now: now)
            try storage.add(entry)
            _ = try loadUnlocked(now: now)
        }
    }

    func load(now: Date = Date()) throws -> [ActivityEntry] {
        try lock.withLock { try loadUnlocked(now: now) }
    }

    func clear() throws {
        try lock.withLock {
            try removeLegacyFileUnlocked()
            try storage.deleteAll()
        }
    }

    /// Only the containing app writes this preference. Failed wipes are retried on its next use.
    func clearIfReinstalled(defaults: UserDefaults, installedKey: String) throws {
        try lock.withLock {
            try removeLegacyFileUnlocked()
            guard !defaults.bool(forKey: installedKey) else { return }
            try storage.deleteAll()
            defaults.set(true, forKey: installedKey)
        }
    }

    func removeLegacyFile() throws {
        try lock.withLock { try removeLegacyFileUnlocked() }
    }

    private func removeLegacyFileUnlocked() throws {
        guard let legacyFileURL else { return }
        do {
            try FileManager.default.removeItem(at: legacyFileURL)
        } catch CocoaError.fileNoSuchFile {
            // Absence is the desired state. Other errors must not be mistaken for success.
        }
    }

    private func loadUnlocked(now: Date) throws -> [ActivityEntry] {
        try removeLegacyFileUnlocked()
        let items = try storage.items()
        let decoder = JSONDecoder()
        var entries: [ActivityEntry] = []
        for item in items {
            if let data = item.data, let entry = try? decoder.decode(ActivityEntry.self, from: data),
               entry.id.uuidString == item.account {
                entries.append(entry)
            } else {
                // Delete corrupt payloads by their actual account, not an untrusted decoded ID.
                try storage.delete(account: item.account)
            }
        }
        let cutoff = now.addingTimeInterval(-Double(Self.retentionDays) * 86_400)
        let sorted = entries.sorted {
            $0.received == $1.received ? $0.id.uuidString > $1.id.uuidString : $0.received > $1.received
        }
        // Preserve entries after a backward clock change rather than treating them as corrupt.
        let eligible = sorted.filter { $0.received >= cutoff }
        let kept = Array(eligible.prefix(Self.maxEntries))
        let keptIDs = Set(kept.map(\.id))
        for entry in entries where !keptIDs.contains(entry.id) {
            try storage.delete(account: entry.id.uuidString)
        }
        return kept
    }
}

enum ActivityLog {
    static let retentionDays = ActivityLogStore.retentionDays
    static let maxEntries = ActivityLogStore.maxEntries
    private static let installedKey = "activityLogInstalled"
    private static let logger = Logger(subsystem: "com.droessmj.sift", category: "ActivityLog")
    private static let store = ActivityLogStore(
        storage: KeychainActivityStorage(accessGroup: Bundle.main.object(forInfoDictionaryKey: "SiftKeychainAccessGroup") as? String),
        legacyFileURL: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("activity.jsonl")
    )

    /// Best effort: storage failures must never prevent the extension from returning its verdict.
    static func record(_ entry: ActivityEntry) {
        do { try store.record(entry) }
        catch { report(error) }
    }

    static func load() throws -> [ActivityEntry] {
        guard let defaults = UserDefaults(suiteName: Sift.appGroup) else { throw ActivityLogError.missingAccessGroup }
        try store.clearIfReinstalled(defaults: defaults, installedKey: installedKey)
        return try store.load()
    }

    static func clear() throws { try store.clear() }

    /// Run in the extension's own container at launch, including upgrades from the fallback design.
    static func removeLegacyFile() {
        do { try store.removeLegacyFile() }
        catch { report(error) }
    }

    static func report(_ error: Error) {
        // Diagnostics deliberately omit sender, keyword, message body, and serialized entries.
        if case ActivityLogError.keychain(let status) = error {
            logger.error("Activity storage operation failed (OSStatus \(status, privacy: .public)).")
        } else {
            logger.error("Activity storage operation failed; no fallback copy was saved.")
        }
    }
}
