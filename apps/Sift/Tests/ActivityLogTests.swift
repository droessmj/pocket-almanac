import Foundation
import Security
import XCTest
@testable import SiftCore

final class ActivityLogTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)
    private var directory: URL!
    private var legacyFile: URL { directory.appendingPathComponent("activity.jsonl") }

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("SiftLoggingTests-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    private func entry(age: TimeInterval = 0) -> ActivityEntry {
        ActivityEntry(received: now.addingTimeInterval(-age), sender: "test sender", verdict: .spam,
                      reason: "keyword \"pineapple\"")
    }

    private func store(_ storage: MemoryActivityStorage) -> ActivityLogStore {
        ActivityLogStore(storage: storage, legacyFileURL: legacyFile)
    }

    func testWritingPrunesExpiredActivityWithoutOpeningTheApp() throws {
        let storage = MemoryActivityStorage()
        let expired = entry(age: 31 * 86_400)
        let boundary = entry(age: 30 * 86_400)
        let recent = entry(age: 29 * 86_400)
        for item in [expired, boundary, recent] { try storage.add(item) }
        let current = entry()
        try store(storage).record(current, now: now)
        XCTAssertEqual(Set(storage.records.keys), Set([boundary, recent, current].map { $0.id.uuidString }))
    }

    func testWritingCapsStoredActivityAndKeepsTheNewestEntries() throws {
        let storage = MemoryActivityStorage()
        let entries = (1...1005).map { entry(age: Double($0)) }
        for item in entries.reversed() { try storage.add(item) }
        let current = entry()
        let log = store(storage)
        try log.record(current, now: now)
        XCTAssertEqual(storage.records.count, 1000)
        XCTAssertEqual(try log.load(now: now).map(\.id), [current.id] + entries.prefix(999).map(\.id))
    }

    func testEqualTimestampsHaveStableRetentionOrder() throws {
        let storage = MemoryActivityStorage()
        for index in 0...1000 {
            var item = entry()
            item.id = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012X", index))!
            try storage.add(item)
        }
        let log = store(storage)
        let first = try log.load(now: now).map(\.id)
        XCTAssertEqual(first.count, 1000)
        XCTAssertEqual(first, try log.load(now: now).map(\.id))
        XCTAssertNil(storage.records["00000000-0000-0000-0000-000000000000"])
    }

    func testBackwardClockChangeDoesNotDeleteRecentHistory() throws {
        let storage = MemoryActivityStorage()
        let item = entry()
        try storage.add(item)
        XCTAssertEqual(try store(storage).load(now: now.addingTimeInterval(-3600)).map(\.id), [item.id])
        XCTAssertNotNil(storage.records[item.id.uuidString])
    }

    func testUnreadableStorageThrowsAndPreventsAdditionalWrites() throws {
        let storage = MemoryActivityStorage()
        storage.failRead = true
        let log = store(storage)
        XCTAssertThrowsError(try log.load(now: now))
        XCTAssertThrowsError(try log.record(entry(), now: now))
        XCTAssertEqual(storage.addCalls, 0)
        XCTAssertTrue(storage.records.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyFile.path))
    }

    func testWriteFailureRemovesLegacyFileWithoutCreatingAnotherCopy() throws {
        let storage = MemoryActivityStorage()
        storage.failAdd = true
        try Data("old sensitive diagnostic copy".utf8).write(to: legacyFile)
        XCTAssertThrowsError(try store(storage).record(entry(), now: now))
        XCTAssertTrue(storage.records.isEmpty)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), [])
    }

    func testLoadPurgesMalformedMissingAndMismatchedPayloads() throws {
        let storage = MemoryActivityStorage()
        let valid = entry()
        try storage.add(valid)
        storage.records["corrupt"] = Data("not JSON".utf8)
        storage.missingDataAccounts = ["missing"]
        storage.records["wrong account"] = try JSONEncoder().encode(entry())
        XCTAssertEqual(try store(storage).load(now: now).map(\.id), [valid.id])
        XCTAssertEqual(Set(storage.records.keys), [valid.id.uuidString])
        XCTAssertTrue(storage.missingDataAccounts.isEmpty)
    }

    func testOlderEntriesWithDiagnosticStatusStillDecode() throws {
        let storage = MemoryActivityStorage()
        let valid = entry()
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(valid)) as? [String: Any])
        object["keychainStatus"] = -34018
        storage.records[valid.id.uuidString] = try JSONSerialization.data(withJSONObject: object)
        XCTAssertEqual(try store(storage).load(now: now).map(\.id), [valid.id])
    }

    func testFailedPruningIsReportedAndDoesNotAppendMoreActivity() throws {
        let storage = MemoryActivityStorage()
        try storage.add(entry(age: 31 * 86_400))
        storage.failDelete = true
        let previousAddCalls = storage.addCalls
        let log = store(storage)
        XCTAssertThrowsError(try log.load(now: now))
        XCTAssertThrowsError(try log.record(entry(), now: now))
        XCTAssertEqual(storage.addCalls, previousAddCalls)
        XCTAssertEqual(storage.records.count, 1)
    }

    func testClearDeletesSavedActivityAndLegacyCopy() throws {
        let storage = MemoryActivityStorage()
        try storage.add(entry())
        try Data("old diagnostic copy".utf8).write(to: legacyFile)
        try store(storage).clear()
        XCTAssertTrue(storage.records.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyFile.path))
    }

    func testFailedReinstallWipeIsRetriedBeforeMarkingInstallationComplete() throws {
        let suite = "SiftLoggingTests-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let storage = MemoryActivityStorage()
        try storage.add(entry())
        let log = store(storage)
        storage.failClear = true
        XCTAssertThrowsError(try log.clear())
        XCTAssertThrowsError(try log.clearIfReinstalled(defaults: defaults, installedKey: "installed"))
        XCTAssertFalse(defaults.bool(forKey: "installed"))
        XCTAssertEqual(storage.records.count, 1)
        storage.failClear = false
        try log.clearIfReinstalled(defaults: defaults, installedKey: "installed")
        XCTAssertTrue(defaults.bool(forKey: "installed"))
        XCTAssertTrue(storage.records.isEmpty)
        let fresh = entry()
        try storage.add(fresh)
        try log.clearIfReinstalled(defaults: defaults, installedKey: "installed")
        XCTAssertNotNil(storage.records[fresh.id.uuidString])
    }

    func testPruningDoesNotDeleteAnotherProcessEntryOutsideItsSnapshot() throws {
        let storage = MemoryActivityStorage()
        try storage.add(entry(age: 31 * 86_400))
        let concurrent = entry()
        storage.afterSnapshot = { try storage.add(concurrent) }
        _ = try store(storage).load(now: now)
        XCTAssertEqual(Set(storage.records.keys), [concurrent.id.uuidString])
    }

    func testMissingSharedGroupNeverFallsBackToAnUnsharedKeychain() {
        for group in [nil, "", "$(AppIdentifierPrefix)com.droessmj.sift.shared"] as [String?] {
            let storage = KeychainActivityStorage(accessGroup: group)
            XCTAssertThrowsError(try storage.items())
            XCTAssertThrowsError(try storage.add(entry()))
            XCTAssertThrowsError(try storage.delete(account: "anything"))
            XCTAssertThrowsError(try storage.deleteAll())
        }
    }

    func testConcurrentWritesInOneProcessPreserveIndependentEntries() throws {
        let storage = MemoryActivityStorage()
        let log = store(storage)
        let errorsLock = NSLock()
        var errors: [Error] = []
        DispatchQueue.concurrentPerform(iterations: 100) { index in
            do { try log.record(entry(age: Double(index)), now: now) }
            catch { errorsLock.withLock { errors.append(error) } }
        }
        XCTAssertTrue(errors.isEmpty)
        XCTAssertEqual(try log.load(now: now).count, 100)
    }
}

private final class MemoryActivityStorage: ActivityLogStorage {
    var records: [String: Data] = [:]
    var missingDataAccounts: Set<String> = []
    var failRead = false
    var failAdd = false
    var failDelete = false
    var failClear = false
    var addCalls = 0
    var afterSnapshot: (() throws -> Void)?

    func items() throws -> [StoredActivityItem] {
        if failRead { throw ActivityLogError.keychain(errSecInteractionNotAllowed) }
        let snapshot = records.map { StoredActivityItem(account: $0.key, data: $0.value) }
            + missingDataAccounts.map { StoredActivityItem(account: $0, data: nil) }
        let callback = afterSnapshot
        afterSnapshot = nil
        try callback?()
        return snapshot
    }

    func add(_ entry: ActivityEntry) throws {
        addCalls += 1
        if failAdd { throw ActivityLogError.keychain(errSecMissingEntitlement) }
        records[entry.id.uuidString] = try JSONEncoder().encode(entry)
    }

    func delete(account: String) throws {
        if failDelete { throw ActivityLogError.keychain(errSecInteractionNotAllowed) }
        records.removeValue(forKey: account)
        missingDataAccounts.remove(account)
    }

    func deleteAll() throws {
        if failClear { throw ActivityLogError.keychain(errSecInteractionNotAllowed) }
        records.removeAll()
        missingDataAccounts.removeAll()
    }
}
