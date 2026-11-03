// Copyright (c) 2026 Michael Droessler
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

import Foundation

/// Deletes known old log files without opening or decoding their contents.
enum LegacyLogFileCleanup {
    static func removePrivateLog() throws {
        let files = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .map { $0.appendingPathComponent("activity.jsonl") }
        try remove(files)
    }

    static func remove(_ files: [URL]) throws {
        var firstError: Error?
        for file in files {
            do { try FileManager.default.removeItem(at: file) }
            catch CocoaError.fileNoSuchFile { }
            catch { if firstError == nil { firstError = error } }
        }
        if let firstError { throw firstError }
    }
}
