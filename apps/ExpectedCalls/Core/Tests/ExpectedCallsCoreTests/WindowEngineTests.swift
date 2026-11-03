import Foundation
import XCTest
@testable import ExpectedCallsCore

final class WindowEngineTests: XCTestCase {
    private let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    private let secondID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

    private func date(_ seconds: TimeInterval) -> Date { Date(timeIntervalSince1970: seconds) }

    private func window(id: UUID? = nil, start: TimeInterval = 100, end: TimeInterval = 200, revision: Int = 1) -> ExpectedCallWindow {
        ExpectedCallWindow(id: id ?? firstID, start: date(start), end: date(end), revision: revision)
    }

    private func confirmed(_ windows: [ExpectedCallWindow]) -> CallState {
        var state = CallState(windows: windows)
        for window in windows { WindowEngine.confirmSetup(windowID: window.id, in: &state) }
        return state
    }

    @discardableResult
    private func evaluate(_ boundary: CallBoundary, _ window: ExpectedCallWindow, at seconds: TimeInterval, in state: inout CallState) -> CallDecision {
        WindowEngine.evaluate(boundary: boundary, windowID: window.id, revision: window.revision, now: date(seconds), state: &state)
    }

    func testSetupMutationsPreserveLastIntentEvaluation() throws {
        let window = window()
        let message = "Previous intent evaluation"
        var state = CallState(lastEvaluation: message)
        try WindowEngine.save(window, in: &state, now: date(0))
        XCTAssertEqual(state.lastEvaluation, message)
        WindowEngine.confirmSetup(windowID: window.id, in: &state)
        XCTAssertEqual(state.lastEvaluation, message)
        WindowEngine.cancel(windowID: window.id, in: &state)
        XCTAssertEqual(state.lastEvaluation, message)
    }

    func testInitialOccurrenceIsUnconfirmedAndUsesChicagoCSTAbsoluteInstants() throws {
        let state = CallState.initial
        let window = try XCTUnwrap(state.windows.first)
        XCTAssertEqual(state.windows.count, 1)
        XCTAssertTrue(state.confirmedRevisions.isEmpty)
        XCTAssertTrue(state.sessions.isEmpty)
        XCTAssertNil(state.lastEvaluation)
        XCTAssertEqual(window.timeZoneIdentifier, "America/Chicago")
        let formatter = ISO8601DateFormatter()
        XCTAssertEqual(formatter.string(from: window.start), "2026-11-04T21:55:00Z")
        XCTAssertEqual(formatter.string(from: window.end), "2026-11-04T22:15:00Z")
        let zone = try XCTUnwrap(TimeZone(identifier: window.timeZoneIdentifier))
        XCTAssertEqual(zone.secondsFromGMT(for: window.start), -6 * 60 * 60)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let start = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: window.start)
        XCTAssertEqual(start, DateComponents(year: 2026, month: 11, day: 4, hour: 15, minute: 55))
        let end = calendar.dateComponents([.hour, .minute], from: window.end)
        XCTAssertEqual(end.hour, 16)
        XCTAssertEqual(end.minute, 15)
    }

    func testOpeningUsesHalfOpenIntervalIncludingFractionalBoundary() {
        let window = window()
        for (time, expected) in [(99.999, CallDecision.noChange), (100, .allow), (199.999, .allow), (200, .noChange), (201, .noChange)] {
            var state = confirmed([window])
            XCTAssertEqual(evaluate(.opening, window, at: time, in: &state), expected, "time=\(time)")
            XCTAssertEqual(state.sessions.count, expected == .allow ? 1 : 0)
            XCTAssertNotNil(state.lastEvaluation)
        }
    }

    func testOpeningRequiresExactIdentityRevisionAndSetup() {
        let window = window()
        var state = CallState(windows: [window])
        XCTAssertEqual(evaluate(.opening, window, at: 150, in: &state), .noChange)
        WindowEngine.confirmSetup(windowID: window.id, in: &state)
        var wrongID = window
        wrongID.id = secondID
        var wrongRevision = window
        wrongRevision.revision += 1
        XCTAssertEqual(evaluate(.opening, wrongID, at: 150, in: &state), .noChange)
        XCTAssertEqual(evaluate(.opening, wrongRevision, at: 150, in: &state), .noChange)
        XCTAssertTrue(state.sessions.isEmpty)
        XCTAssertEqual(evaluate(.opening, window, at: 150, in: &state), .allow)
    }

    func testDuplicateOpeningDoesNotIssueAnotherAllowOrDuplicateResponsibility() {
        let window = window()
        var state = confirmed([window])
        XCTAssertEqual(evaluate(.opening, window, at: 100, in: &state), .allow)
        XCTAssertEqual(state.sessions, [CallSession(windowID: window.id, revision: 1, end: window.end)])
        XCTAssertEqual(evaluate(.opening, window, at: 101, in: &state), .noChange)
        XCTAssertEqual(state.sessions.count, 1)
    }

    func testClosingCannotRestoreBeforeOwnEndAndRestoresOnlyOnce() {
        let window = window()
        var state = confirmed([window])
        XCTAssertEqual(evaluate(.closing, window, at: 200, in: &state), .noChange)
        XCTAssertEqual(evaluate(.opening, window, at: 150, in: &state), .allow)
        XCTAssertEqual(evaluate(.closing, window, at: 199.999, in: &state), .noChange)
        XCTAssertEqual(state.sessions.count, 1)
        XCTAssertEqual(evaluate(.closing, window, at: 200, in: &state), .restoreSilence)
        XCTAssertTrue(state.sessions.isEmpty)
        XCTAssertEqual(evaluate(.closing, window, at: 201, in: &state), .noChange)
        XCTAssertEqual(evaluate(.closing, window, at: 100_000, in: &state), .noChange)
    }

    func testLateOwnedCloseRecoversButStaleOpeningNeverReopens() {
        let window = window()
        var state = confirmed([window])
        XCTAssertEqual(evaluate(.opening, window, at: 150, in: &state), .allow)
        XCTAssertEqual(evaluate(.opening, window, at: 86_550, in: &state), .noChange)
        XCTAssertEqual(evaluate(.closing, window, at: 86_600, in: &state), .restoreSilence)
        XCTAssertEqual(evaluate(.closing, window, at: 172_800, in: &state), .noChange)
    }

    func testCancelBeforeOpeningPreventsEitherAutomationChangingSettings() {
        let window = window()
        var state = confirmed([window])
        WindowEngine.cancel(windowID: window.id, in: &state)
        XCTAssertTrue(state.windows.isEmpty)
        XCTAssertTrue(state.confirmedRevisions.isEmpty)
        XCTAssertEqual(evaluate(.opening, window, at: 150, in: &state), .noChange)
        XCTAssertEqual(evaluate(.closing, window, at: 200, in: &state), .noChange)
    }

    func testCancelAfterAllowRetainsIndependentOriginalClosingPath() {
        let window = window()
        var state = confirmed([window])
        XCTAssertEqual(evaluate(.opening, window, at: 150, in: &state), .allow)
        let owned = state.sessions
        WindowEngine.cancel(windowID: window.id, in: &state)
        XCTAssertTrue(state.windows.isEmpty)
        XCTAssertEqual(state.sessions, owned)
        XCTAssertEqual(evaluate(.closing, window, at: 199, in: &state), .noChange)
        XCTAssertEqual(evaluate(.closing, window, at: 300, in: &state), .restoreSilence)
    }

    func testEditingIncrementsStoredRevisionInvalidatesOnlyEditedSetupAndKeepsClose() throws {
        let original = window()
        let other = window(id: secondID, start: 400, end: 500)
        var state = confirmed([original, other])
        XCTAssertEqual(evaluate(.opening, original, at: 120, in: &state), .allow)
        var replacement = original
        replacement.start = date(150)
        replacement.end = date(250)
        replacement.revision = 99
        try WindowEngine.save(replacement, in: &state, now: date(130))
        replacement = state.windows[0]
        XCTAssertEqual(replacement.revision, 2)
        XCTAssertNil(state.confirmedRevisions[original.id.uuidString])
        XCTAssertEqual(state.confirmedRevisions[other.id.uuidString], 1)
        XCTAssertEqual(state.sessions, [CallSession(windowID: original.id, revision: 1, end: date(200))])
        WindowEngine.confirmSetup(windowID: replacement.id, in: &state)
        XCTAssertEqual(state.sessions.count, 1)
        XCTAssertEqual(evaluate(.opening, original, at: 160, in: &state), .noChange)
        XCTAssertEqual(evaluate(.opening, replacement, at: 160, in: &state), .noChange)
        XCTAssertEqual(evaluate(.closing, replacement, at: 260, in: &state), .noChange)
        XCTAssertEqual(evaluate(.closing, original, at: 200, in: &state), .noChange)
        XCTAssertEqual(state.sessions, [CallSession(windowID: replacement.id, revision: 2, end: date(250))])
        XCTAssertEqual(evaluate(.closing, replacement, at: 250, in: &state), .restoreSilence)
    }

    func testEditToNonoverlappingFutureRetainsOldCloseThenAllowsNewOpening() throws {
        let original = window()
        var state = confirmed([original])
        XCTAssertEqual(evaluate(.opening, original, at: 100, in: &state), .allow)
        var replacement = window(start: 300, end: 400)
        try WindowEngine.save(replacement, in: &state, now: date(150))
        replacement = state.windows[0]
        WindowEngine.confirmSetup(windowID: replacement.id, in: &state)
        XCTAssertEqual(evaluate(.closing, original, at: 200, in: &state), .restoreSilence)
        XCTAssertEqual(evaluate(.opening, replacement, at: 300, in: &state), .allow)
        XCTAssertEqual(evaluate(.closing, original, at: 400, in: &state), .noChange)
        XCTAssertEqual(state.sessions.count, 1)
        XCTAssertEqual(evaluate(.closing, replacement, at: 400, in: &state), .restoreSilence)
    }

    func testSaveAddsIndependentFutureOccurrencesAndCancelIsTargeted() throws {
        let first = window()
        let second = window(id: secondID, start: 300, end: 400)
        var state = CallState()
        try WindowEngine.save(first, in: &state, now: date(0))
        WindowEngine.confirmSetup(windowID: first.id, in: &state)
        try WindowEngine.save(second, in: &state, now: date(0))
        XCTAssertEqual(state.windows, [first, second])
        XCTAssertEqual(state.confirmedRevisions[first.id.uuidString], 1)
        WindowEngine.cancel(windowID: second.id, in: &state)
        XCTAssertEqual(state.windows, [first])
        XCTAssertEqual(state.confirmedRevisions[first.id.uuidString], 1)
    }

    func testOverlappingOccurrencesKeepAllowanceUntilFinalOwnedClose() {
        let first = window()
        let second = window(id: secondID, start: 150, end: 250)
        var state = confirmed([first, second])
        XCTAssertEqual(evaluate(.opening, first, at: 100, in: &state), .allow)
        XCTAssertEqual(evaluate(.opening, second, at: 150, in: &state), .allow)
        XCTAssertEqual(evaluate(.closing, first, at: 200, in: &state), .noChange)
        XCTAssertEqual(state.sessions, [CallSession(windowID: second.id, revision: 1, end: date(250))])
        XCTAssertEqual(evaluate(.closing, first, at: 250, in: &state), .noChange)
        XCTAssertEqual(evaluate(.closing, second, at: 250, in: &state), .restoreSilence)
    }

    func testMissedOverlappingOpeningTransfersResponsibilityToConfirmedOccurrence() {
        let first = window()
        let second = window(id: secondID, start: 150, end: 250)
        var state = confirmed([first, second])
        XCTAssertEqual(evaluate(.opening, first, at: 100, in: &state), .allow)
        XCTAssertEqual(evaluate(.closing, first, at: 200, in: &state), .noChange)
        XCTAssertEqual(state.sessions, [CallSession(windowID: second.id, revision: 1, end: date(250))])
        XCTAssertEqual(evaluate(.opening, second, at: 210, in: &state), .noChange)
        XCTAssertEqual(evaluate(.closing, second, at: 250, in: &state), .restoreSilence)
    }

    func testUnconfirmedOverlapDoesNotSuppressRestorationOrAcquireOwnership() {
        let first = window()
        let second = window(id: secondID, start: 150, end: 250)
        var state = confirmed([first])
        state.windows.append(second)
        XCTAssertEqual(evaluate(.opening, first, at: 100, in: &state), .allow)
        XCTAssertEqual(evaluate(.closing, first, at: 200, in: &state), .restoreSilence)
        XCTAssertTrue(state.sessions.isEmpty)
        XCTAssertEqual(evaluate(.closing, second, at: 250, in: &state), .noChange)
    }

    func testAbuttingConfirmedOccurrenceTransfersAtExactHalfOpenBoundary() {
        let first = window()
        let second = window(id: secondID, start: 200, end: 300)
        var state = confirmed([first, second])
        XCTAssertEqual(evaluate(.opening, first, at: 100, in: &state), .allow)
        XCTAssertEqual(evaluate(.closing, first, at: 200, in: &state), .noChange)
        XCTAssertEqual(state.sessions.first?.windowID, second.id)
        XCTAssertEqual(evaluate(.closing, second, at: 300, in: &state), .restoreSilence)
    }

    func testLateCloseCollectsAllExpiredSessionsOnceButWrongTokenCannot() {
        let first = window()
        let second = window(id: secondID, start: 150, end: 250)
        var state = confirmed([first, second])
        XCTAssertEqual(evaluate(.opening, first, at: 100, in: &state), .allow)
        XCTAssertEqual(evaluate(.opening, second, at: 150, in: &state), .allow)
        var wrongToken = first
        wrongToken.revision = 99
        XCTAssertEqual(evaluate(.closing, wrongToken, at: 500, in: &state), .noChange)
        XCTAssertEqual(state.sessions.count, 2)
        XCTAssertEqual(evaluate(.closing, first, at: 500, in: &state), .restoreSilence)
        XCTAssertTrue(state.sessions.isEmpty)
        XCTAssertEqual(evaluate(.closing, second, at: 500, in: &state), .noChange)
    }

    func testCancelledOverlapStillOwnsItsOriginalEnd() {
        let first = window()
        let second = window(id: secondID, start: 150, end: 250)
        var state = confirmed([first, second])
        XCTAssertEqual(evaluate(.opening, first, at: 100, in: &state), .allow)
        XCTAssertEqual(evaluate(.opening, second, at: 150, in: &state), .allow)
        WindowEngine.cancel(windowID: second.id, in: &state)
        XCTAssertEqual(evaluate(.closing, first, at: 200, in: &state), .noChange)
        XCTAssertEqual(evaluate(.closing, second, at: 250, in: &state), .restoreSilence)
    }

    func testRestorationDoesNotWaitForUnstartedFutureOccurrence() {
        let first = window()
        let second = window(id: secondID, start: 300, end: 400)
        var state = confirmed([first, second])
        XCTAssertEqual(evaluate(.opening, first, at: 100, in: &state), .allow)
        XCTAssertEqual(evaluate(.closing, first, at: 200, in: &state), .restoreSilence)
        XCTAssertTrue(state.sessions.isEmpty)
    }

    func testSaveRejectsInvalidSchedulesWithoutMutatingState() {
        let valid = window()
        let baseline = confirmed([valid])
        var invalid: [ExpectedCallWindow] = [window(start: 200, end: 200), window(start: 201, end: 200)]
        var nonfinite = valid
        nonfinite.start = Date(timeIntervalSinceReferenceDate: .infinity)
        invalid.append(nonfinite)
        nonfinite = valid
        nonfinite.end = Date(timeIntervalSinceReferenceDate: .nan)
        invalid.append(nonfinite)
        var badZone = valid
        badZone.timeZoneIdentifier = "Not/A_Time_Zone"
        invalid.append(badZone)
        var badRevision = valid
        badRevision.revision = 0
        invalid.append(badRevision)
        for window in invalid {
            var state = baseline
            XCTAssertThrowsError(try WindowEngine.save(window, in: &state, now: date(0)))
            XCTAssertEqual(state, baseline)
        }
        for now in [date(100), date(150), Date(timeIntervalSinceReferenceDate: .nan)] {
            var state = baseline
            XCTAssertThrowsError(try WindowEngine.save(valid, in: &state, now: now))
            XCTAssertEqual(state, baseline)
        }
    }

    func testRevisionExhaustionDoesNotTrapOrModifyState() {
        let window = window(revision: Int.max)
        var state = confirmed([window])
        let original = state
        XCTAssertThrowsError(try WindowEngine.save(window, in: &state, now: date(0))) { error in
            XCTAssertEqual(error as? WindowValidationError, .exhaustedRevision)
        }
        XCTAssertEqual(state, original)
    }

    func testResavingCancelledActiveIdentityDoesNotReuseRetainedToken() throws {
        let window = window()
        var state = confirmed([window])
        XCTAssertEqual(evaluate(.opening, window, at: 100, in: &state), .allow)
        WindowEngine.cancel(windowID: window.id, in: &state)
        let replacement = self.window(start: 300, end: 400)
        try WindowEngine.save(replacement, in: &state, now: date(150))
        XCTAssertEqual(state.windows.first?.revision, 2)
        XCTAssertEqual(state.sessions.first?.revision, 1)
    }

    func testTimeZoneDisplayMetadataDoesNotShiftAbsoluteEvaluation() throws {
        var first = window()
        first.timeZoneIdentifier = "Asia/Tokyo"
        var state = confirmed([first])
        XCTAssertEqual(evaluate(.opening, first, at: 100, in: &state), .allow)
        XCTAssertEqual(evaluate(.closing, first, at: 200, in: &state), .restoreSilence)
        let data = try JSONEncoder().encode(first)
        let restored = try JSONDecoder().decode(ExpectedCallWindow.self, from: data)
        XCTAssertEqual(restored.start, date(100))
        XCTAssertEqual(restored.end, date(200))
        XCTAssertEqual(restored.timeZoneIdentifier, "Asia/Tokyo")
    }

    func testNonfiniteEvaluationCannotConsumeOwnedResponsibility() {
        let window = window()
        var state = confirmed([window])
        XCTAssertEqual(evaluate(.opening, window, at: 100, in: &state), .allow)
        let sessions = state.sessions
        XCTAssertEqual(WindowEngine.evaluate(boundary: .closing, windowID: window.id, revision: 1,
                                            now: Date(timeIntervalSinceReferenceDate: .nan), state: &state), .noChange)
        XCTAssertEqual(state.sessions, sessions)
    }
}
