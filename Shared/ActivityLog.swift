// Copyright (c) 2026 Michael Droessler
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

import Darwin
import Foundation
import Security
import os

/// One message the filter processed. The message body is never stored.
struct ActivityEntry: Codable, Identifiable {
    enum Verdict: String, Codable { case spam, allowed }

    var id = UUID()
    var received: Date
    var sender: String
    var verdict: Verdict
    var reason: String
    /// Filter extension's memory limit at the time (footprint + available), for sizing the future classifier.
    var filterMemoryLimitMB: Double?
    /// Set only on fallback copies: the keychain status that prevented the shared write.
    var keychainStatus: Int32?
}

/// Activity log shared between the filter and the app via a keychain access group.
/// The extension can't write shared containers, so each entry is its own keychain item;
/// separate items also keep concurrent filter invocations from overwriting each other.
enum ActivityLog {
    static let logger = Logger(subsystem: "com.droessmj.sift", category: "activity")
    private static let service = "com.droessmj.sift.activity"
    private static let accessGroup = Bundle.main.object(forInfoDictionaryKey: "SiftKeychainAccessGroup") as? String
    /// Entries older than this, or beyond `maxEntries`, are deleted when the app loads the log.
    static let retentionDays = 30
    static let maxEntries = 1000
    private static let installedKey = "activityLogInstalled"

    /// Filter side: store in the shared keychain; on failure keep a copy in the extension's own
    /// container (pull with scripts/pull-filter-log.sh) so the entry and the error aren't lost.
    static func record(_ entry: ActivityEntry) {
        let status = add(entry)
        guard status != errSecSuccess else { return }
        logger.error("keychain write failed: \(status, privacy: .public)")
        var copy = entry
        copy.keychainStatus = status
        appendLocal(copy)
    }

    /// App side: returns entries newest first, deleting any past the retention window or count cap.
    static func load() -> [ActivityEntry] {
        var query = baseQuery()
        query[kSecMatchLimit] = kSecMatchLimitAll
        query[kSecReturnAttributes] = true
        query[kSecReturnData] = true
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let items = result as? [[CFString: Any]] else { return [] }
        let decoder = JSONDecoder()
        let entries = items
            .compactMap { ($0[kSecValueData] as? Data).flatMap { try? decoder.decode(ActivityEntry.self, from: $0) } }
        let (kept, expired) = retain(entries, now: Date())
        for entry in expired { delete(entry.id) }
        return kept
    }

    /// Splits entries into those to keep (newest first, within `retentionDays`, at most `maxEntries`) and the rest.
    static func retain(_ entries: [ActivityEntry], now: Date) -> (kept: [ActivityEntry], expired: [ActivityEntry]) {
        let cutoff = now.addingTimeInterval(-Double(retentionDays) * 86_400)
        let sorted = entries.sorted { $0.received > $1.received }
        let kept = Array(sorted.prefix(maxEntries).filter { $0.received >= cutoff })
        let keptIDs = Set(kept.map(\.id))
        return (kept, sorted.filter { !keptIDs.contains($0.id) })
    }

    static func clear() {
        SecItemDelete(baseQuery() as CFDictionary)
    }

    /// Keychain items outlive app deletion; the App Group container doesn't. A missing marker therefore
    /// means a fresh install, so entries left by a previous install are wiped.
    static func clearIfReinstalled() {
        guard let defaults = UserDefaults(suiteName: Sift.appGroup), !defaults.bool(forKey: installedKey) else { return }
        clear()
        defaults.set(true, forKey: installedKey)
    }

    private static func delete(_ id: UUID) {
        var query = baseQuery()
        query[kSecAttrAccount] = id.uuidString
        SecItemDelete(query as CFDictionary)
    }

    private static func add(_ entry: ActivityEntry) -> OSStatus {
        guard accessGroup != nil, let data = try? JSONEncoder().encode(entry) else { return errSecParam }
        var item = baseQuery()
        item[kSecAttrAccount] = entry.id.uuidString
        item[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        item[kSecValueData] = data
        return SecItemAdd(item as CFDictionary, nil)
    }

    private static func baseQuery() -> [CFString: Any] {
        var query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrService: service]
        if let accessGroup { query[kSecAttrAccessGroup] = accessGroup }
        return query
    }

    /// Diagnostic copy only: drops the sender and stops at 64 KB, since nothing prunes this file.
    private static func appendLocal(_ entry: ActivityEntry) {
        var redacted = entry
        redacted.sender = "redacted"
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("activity.jsonl"),
              var line = try? JSONEncoder().encode(redacted) else { return }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard size < 65_536 else { return }
        line.append(0x0A)
        do {
            if let handle = try? FileHandle(forWritingTo: url) {
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: line)
            } else {
                try line.write(to: url, options: .atomic)
            }
        } catch {
            logger.error("local activity write failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

enum Memory {
    /// Current process's jetsam limit in MB: physical footprint + memory available before termination.
    static func limitMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        let footprint = kr == KERN_SUCCESS ? info.phys_footprint : 0
        return Double(footprint + UInt64(os_proc_available_memory())) / 1_048_576
    }
}
