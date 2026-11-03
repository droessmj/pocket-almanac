import Dispatch
import Foundation
import XCTest
@testable import ExpectedCallsCore

final class CallStoreTests: XCTestCase {
    private struct Envelope: Codable {
        var version = 1
        var state: CallState
    }

    private enum TestError: Error {
        case intentionalFailure
        case invalidCounter
    }

    private final class ErrorCollector: @unchecked Sendable {
        private let lock = NSLock()
        private var values: [String] = []

        func append(_ error: Error) {
            lock.lock()
            defer { lock.unlock() }
            values.append(String(describing: error))
        }

        var messages: [String] {
            lock.lock()
            defer { lock.unlock() }
            return values
        }
    }

    private func withStore(_ body: (CallStore, URL) throws -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ExpectedCallsTests-\(UUID())", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("nested/state.json")
        try body(CallStore(url: url), url)
    }

    private func fixture() -> CallState {
        let first = ExpectedCallWindow(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, label: "Clinic callback",
            start: Date(timeIntervalSinceReferenceDate: 1_000.125), end: Date(timeIntervalSinceReferenceDate: 2_000.875),
            timeZoneIdentifier: "America/Chicago", revision: 3
        )
        let second = ExpectedCallWindow(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, label: "Delivery",
            start: Date(timeIntervalSinceReferenceDate: 3_000), end: Date(timeIntervalSinceReferenceDate: 4_000),
            timeZoneIdentifier: "Asia/Tokyo"
        )
        // The session intentionally belongs to a cancelled/edited occurrence, not a configured revision.
        return CallState(
            windows: [first, second], confirmedRevisions: [first.id.uuidString: 3],
            sessions: [CallSession(windowID: second.id, revision: 7, end: Date(timeIntervalSinceReferenceDate: 2_500))],
            lastEvaluation: "Retained closing responsibility"
        )
    }

    func testMissingFileInitializesVersionedStorageExactlyOnce() throws {
        try withStore { store, url in
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
            let initial = try store.load()
            XCTAssertEqual(initial, .initial)
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            let bytes = try Data(contentsOf: url)
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
            XCTAssertEqual(object["version"] as? Int, 1)
            XCTAssertNotNil(object["state"])
            XCTAssertEqual(try CallStore(url: url).load(), initial)
            XCTAssertEqual(try Data(contentsOf: url), bytes)
        }
    }

    func testUpdateInitializesAbsentStoreAndReturnsClosureValue() throws {
        try withStore { store, _ in
            let result = try store.update { state in
                XCTAssertEqual(state, .initial)
                state.lastEvaluation = "first transaction"
                return 42
            }
            XCTAssertEqual(result, 42)
            XCTAssertEqual(try store.load().lastEvaluation, "first transaction")
        }
    }

    func testRoundTripPreservesMultipleWindowsRevisionsDatesAndRetainedSessions() throws {
        let expected = fixture()
        try withStore { store, url in
            try store.update { $0 = expected }
            XCTAssertEqual(try CallStore(url: url).load(), expected)
        }
    }

    func testThrowingTransactionDoesNotPersistPartialMutation() throws {
        try withStore { store, url in
            let original = try store.load()
            let bytes = try Data(contentsOf: url)
            XCTAssertThrowsError(try store.update { state -> Void in
                state.windows.removeAll()
                throw TestError.intentionalFailure
            }) { error in
                XCTAssertTrue(error is TestError)
            }
            XCTAssertEqual(try Data(contentsOf: url), bytes)
            XCTAssertEqual(try store.load(), original)
        }
    }

    func testInvalidTransactionDoesNotReplaceExistingBytes() throws {
        try withStore { store, url in
            let original = try store.load()
            let bytes = try Data(contentsOf: url)
            XCTAssertThrowsError(try store.update { state in
                state.windows[0].end = state.windows[0].start
            })
            XCTAssertEqual(try Data(contentsOf: url), bytes)
            XCTAssertEqual(try store.load(), original)
        }
    }

    func testCorruptFileIsNeverSilentlyResetByLoadOrUpdate() throws {
        try withStore { store, url in
            _ = try store.load()
            let corrupt = Data("not JSON and not a call state".utf8)
            try corrupt.write(to: url)
            XCTAssertThrowsError(try store.load())
            var invoked = false
            XCTAssertThrowsError(try store.update { _ in invoked = true })
            XCTAssertFalse(invoked)
            XCTAssertEqual(try Data(contentsOf: url), corrupt)
        }
    }

    func testUnsupportedVersionIsRejectedBeforeDecodingItsStateAndPreserved() throws {
        try withStore { store, url in
            _ = try store.load()
            let unsupported = Data("{\"version\":99,\"state\":\"unrecognized future format\"}".utf8)
            try unsupported.write(to: url)
            XCTAssertThrowsError(try store.load()) { error in
                XCTAssertEqual(error as? CallStoreError, .unsupportedVersion(99))
            }
            XCTAssertThrowsError(try store.update { $0 = .initial })
            XCTAssertEqual(try Data(contentsOf: url), unsupported)
        }
    }

    func testMissingEnvelopeVersionAndTruncatedStateAreRejected() throws {
        for bytes in [Data("{}".utf8), Data("{\"version\":1,\"state\":{}}".utf8), Data("{\"version\":1}".utf8)] {
            try withStore { store, url in
                _ = try store.load()
                try bytes.write(to: url)
                XCTAssertThrowsError(try store.load())
                XCTAssertEqual(try Data(contentsOf: url), bytes)
            }
        }
    }

    func testInconsistentDecodedStateIsRejectedWithoutReplacement() throws {
        let valid = fixture()
        var states: [CallState] = []
        var duplicate = valid
        duplicate.windows.append(valid.windows[0])
        states.append(duplicate)
        var badConfirmation = valid
        badConfirmation.confirmedRevisions[valid.windows[0].id.uuidString] = 2
        states.append(badConfirmation)
        var orphanConfirmation = valid
        orphanConfirmation.confirmedRevisions[UUID().uuidString] = 1
        states.append(orphanConfirmation)
        var badSession = valid
        badSession.sessions[0].revision = 0
        states.append(badSession)
        var duplicateSession = valid
        duplicateSession.sessions.append(valid.sessions[0])
        states.append(duplicateSession)
        var invalidSchedule = valid
        invalidSchedule.windows[0].end = invalidSchedule.windows[0].start
        states.append(invalidSchedule)
        var badTimeZone = valid
        badTimeZone.windows[0].timeZoneIdentifier = "Invalid/Zone"
        states.append(badTimeZone)
        for invalid in states {
            try withStore { store, url in
                _ = try store.load()
                let bytes = try JSONEncoder().encode(Envelope(state: invalid))
                try bytes.write(to: url)
                XCTAssertThrowsError(try store.load())
                XCTAssertThrowsError(try store.update { $0 = valid })
                XCTAssertEqual(try Data(contentsOf: url), bytes)
            }
        }
    }

    func testUnreadableNonfilePathIsNotTreatedAsMissing() throws {
        try withStore { store, url in
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            XCTAssertThrowsError(try store.load())
            XCTAssertThrowsError(try store.update { $0 = .initial })
            var isDirectory: ObjCBool = false
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory))
            XCTAssertTrue(isDirectory.boolValue)
        }
    }

    func testDanglingSymbolicLinkIsNotTreatedAsAbsentStorage() throws {
        try withStore { store, url in
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let missingTarget = url.deletingLastPathComponent().appendingPathComponent("missing.json")
            try FileManager.default.createSymbolicLink(at: url, withDestinationURL: missingTarget)
            XCTAssertThrowsError(try store.load())
            XCTAssertThrowsError(try store.update { $0 = .initial })
            XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: url.path), missingTarget.path)
            XCTAssertFalse(FileManager.default.fileExists(atPath: missingTarget.path))
        }
    }

    func testDirectoryCreationErrorsAreSurfacedWithoutOverwritingObstacle() throws {
        try withStore { _, url in
            let directory = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory.deletingLastPathComponent(), withIntermediateDirectories: true)
            let obstacle = Data("do not replace".utf8)
            try obstacle.write(to: directory)
            let store = CallStore(url: url)
            XCTAssertThrowsError(try store.load())
            XCTAssertEqual(try Data(contentsOf: directory), obstacle)
        }
    }

    func testConcurrentIndependentStoresDoNotLoseReadModifyWriteUpdates() throws {
        try withStore { store, url in
            try store.update { $0.lastEvaluation = "0" }
            let failures = ErrorCollector()
            let iterations = 80
            DispatchQueue.concurrentPerform(iterations: iterations) { _ in
                do {
                    try CallStore(url: url).update { state in
                        guard let text = state.lastEvaluation, let count = Int(text) else {
                            throw TestError.invalidCounter
                        }
                        state.lastEvaluation = String(count + 1)
                    }
                } catch {
                    failures.append(error)
                }
            }
            XCTAssertEqual(failures.messages, [])
            XCTAssertEqual(try store.load().lastEvaluation, String(iterations))
            XCTAssertEqual(try store.load().windows, CallState.initial.windows)
        }
    }

    func testOwnedDecisionSurvivesReloadCancelAndIndependentLateClose() throws {
        try withStore { store, url in
            let start = Date(timeIntervalSince1970: 100)
            let end = Date(timeIntervalSince1970: 200)
            let window = ExpectedCallWindow(start: start, end: end)
            try store.update { state in
                state = CallState()
                try WindowEngine.save(window, in: &state, now: Date(timeIntervalSince1970: 0))
                WindowEngine.confirmSetup(windowID: window.id, in: &state)
            }
            let opening = try store.update { state in
                WindowEngine.evaluate(boundary: .opening, windowID: window.id, revision: 1, now: start, state: &state)
            }
            XCTAssertEqual(opening, .allow)
            let anotherInstance = CallStore(url: url)
            XCTAssertEqual(try anotherInstance.load().sessions.count, 1)
            try anotherInstance.update { state in WindowEngine.cancel(windowID: window.id, in: &state) }
            let cancelled = try store.load()
            XCTAssertTrue(cancelled.windows.isEmpty)
            XCTAssertEqual(cancelled.sessions.count, 1)
            let closing = try CallStore(url: url).update { state in
                WindowEngine.evaluate(boundary: .closing, windowID: window.id, revision: 1,
                                      now: Date(timeIntervalSince1970: 300), state: &state)
            }
            XCTAssertEqual(closing, .restoreSilence)
            XCTAssertTrue(try store.load().sessions.isEmpty)
            let duplicate = try store.update { state in
                WindowEngine.evaluate(boundary: .closing, windowID: window.id, revision: 1,
                                      now: Date(timeIntervalSince1970: 400), state: &state)
            }
            XCTAssertEqual(duplicate, .noChange)
        }
    }

    #if os(iOS)
    func testDirectoryAndAtomicReplacementUseUntilFirstUnlockProtection() throws {
        try withStore { store, url in
            _ = try store.load()
            try store.update { $0.lastEvaluation = "replacement" }
            for path in [url, url.deletingLastPathComponent()] {
                let attributes = try FileManager.default.attributesOfItem(atPath: path.path)
                XCTAssertEqual(attributes[.protectionKey] as? FileProtectionType, .completeUntilFirstUserAuthentication)
            }
        }
    }
    #endif
}
