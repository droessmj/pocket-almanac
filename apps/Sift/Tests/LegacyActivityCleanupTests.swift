import Foundation
import Security
import XCTest
@testable import SiftCore

final class LegacyActivityCleanupTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("BlotterCleanupTests-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }

    func testDeletesOnlyBothOldServicesInTheExplicitAccessGroup() throws {
        var queries: [NSDictionary] = []
        try LegacyActivityCleanup(accessGroup: "TEAM.com.droessmj.sift.shared", deleteKeychainItem: {
            queries.append($0 as NSDictionary)
            return errSecSuccess
        }).run()
        XCTAssertEqual(queries.count, 2)
        XCTAssertEqual(Set(queries.compactMap { $0[kSecAttrService] as? String }),
                       ["com.droessmj.sift.activity", "com.droessmj.sift.keyword-history"])
        for query in queries {
            XCTAssertEqual(query[kSecClass] as? String, kSecClassGenericPassword as String)
            XCTAssertEqual(query[kSecAttrAccessGroup] as? String, "TEAM.com.droessmj.sift.shared")
            XCTAssertEqual(query[kSecAttrSynchronizable] as? Bool, false)
            XCTAssertEqual(query[kSecUseDataProtectionKeychain] as? Bool, true)
            XCTAssertNil(query[kSecReturnData])
            XCTAssertNil(query[kSecReturnAttributes])
            XCTAssertNil(query[kSecValueData])
        }
    }

    func testAlreadyAbsentRecordsAndFilesAreSuccessful() throws {
        try LegacyActivityCleanup(accessGroup: "TEAM.shared", fileURLs: [directory.appendingPathComponent("activity.jsonl")],
                                  deleteKeychainItem: { _ in errSecItemNotFound }).run()
    }

    func testMissingAccessGroupNeverUsesAnUnscopedKeychainQuery() {
        for group in [nil, "", "$(AppIdentifierPrefix)com.droessmj.sift.shared"] as [String?] {
            XCTAssertThrowsError(try LegacyActivityCleanup(accessGroup: group, deleteKeychainItem: { _ in
                XCTFail("Must not delete outside a resolved access group")
                return errSecSuccess
            }).run())
        }
    }

    func testAKeychainFailureStillAttemptsOtherCleanupAndCanRetry() throws {
        let file = directory.appendingPathComponent("activity.jsonl")
        try Data("old log".utf8).write(to: file)
        var calls = 0
        var blocked = true
        let cleanup = LegacyActivityCleanup(accessGroup: "TEAM.shared", fileURLs: [file], deleteKeychainItem: { _ in
            calls += 1
            return blocked ? errSecInteractionNotAllowed : errSecSuccess
        })
        XCTAssertThrowsError(try cleanup.run())
        XCTAssertEqual(calls, 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        blocked = false
        try cleanup.run()
        XCTAssertEqual(calls, 4)
    }

    func testCleanupKeepsKeywordsMatchingOptionsSetupAndUnrelatedFiles() throws {
        let suite = "BlotterCleanupTests-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(["pineapple"], forKey: "keywords")
        defaults.set(true, forKey: "matchCase")
        defaults.set(true, forKey: "setupDone")
        defaults.set(true, forKey: "activityLogInstalled")
        let file = directory.appendingPathComponent("activity.jsonl")
        let unrelated = directory.appendingPathComponent("keywords.json")
        try Data("old log".utf8).write(to: file)
        try Data("keep".utf8).write(to: unrelated)
        try LegacyActivityCleanup(accessGroup: "TEAM.shared", fileURLs: [file],
                                  deleteKeychainItem: { _ in errSecSuccess }).run(defaults: defaults)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertEqual(try Data(contentsOf: unrelated), Data("keep".utf8))
        XCTAssertEqual(defaults.stringArray(forKey: "keywords"), ["pineapple"])
        XCTAssertTrue(defaults.bool(forKey: "matchCase"))
        XCTAssertTrue(defaults.bool(forKey: "setupDone"))
        XCTAssertNil(defaults.object(forKey: "activityLogInstalled"))
    }

    func testFailedFileCleanupIsReportedAndRetriedWithoutSkippingOtherFiles() throws {
        let notDirectory = directory.appendingPathComponent("not-a-directory")
        try Data("block".utf8).write(to: notDirectory)
        let invalidFile = notDirectory.appendingPathComponent("activity.jsonl")
        let validFile = directory.appendingPathComponent("activity.jsonl")
        try Data("old log".utf8).write(to: validFile)
        let cleanup = LegacyActivityCleanup(accessGroup: "TEAM.shared", fileURLs: [invalidFile, validFile],
                                            deleteKeychainItem: { _ in errSecSuccess })
        XCTAssertThrowsError(try cleanup.run())
        XCTAssertFalse(FileManager.default.fileExists(atPath: validFile.path))
        try FileManager.default.removeItem(at: notDirectory)
        try FileManager.default.createDirectory(at: notDirectory, withIntermediateDirectories: false)
        try cleanup.run()
    }
}
