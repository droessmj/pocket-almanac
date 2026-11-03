// Copyright (c) 2026 Michael Droessler
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

import Foundation
import Security

/// Compiled into the containing app only. The old access group is retained solely for deletion.
/// There is no API to read, decode, add, or update activity records.
struct LegacyActivityCleanup {
    let accessGroup: String?
    var fileURLs: [URL] = []
    var deleteKeychainItem: (CFDictionary) -> OSStatus = { SecItemDelete($0) }

    enum CleanupError: Error {
        case missingAccessGroup
        case keychain(OSStatus)
    }

    func run(defaults: UserDefaults? = nil) throws {
        var firstError: Error?
        if let accessGroup, !accessGroup.isEmpty, !accessGroup.contains("$(") {
            for service in ["com.droessmj.sift.activity", "com.droessmj.sift.keyword-history"] {
                let query: [CFString: Any] = [
                    kSecClass: kSecClassGenericPassword,
                    kSecAttrService: service,
                    kSecAttrAccessGroup: accessGroup,
                    kSecUseDataProtectionKeychain: true,
                    kSecAttrSynchronizable: false
                ]
                let status = deleteKeychainItem(query as CFDictionary)
                if status != errSecSuccess && status != errSecItemNotFound && firstError == nil {
                    firstError = CleanupError.keychain(status)
                }
            }
        } else {
            firstError = CleanupError.missingAccessGroup
        }
        // Attempt file cleanup even if Keychain deletion failed. Retry all failures on activation.
        do { try LegacyLogFileCleanup.remove(fileURLs) }
        catch { if firstError == nil { firstError = error } }
        if let firstError { throw firstError }
        defaults?.removeObject(forKey: "activityLogInstalled")
    }
}
