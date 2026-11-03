import Foundation

public enum WindowEngine {
    public static func save(_ window: ExpectedCallWindow, in state: inout CallState, now: Date) throws {
        try validate(window)
        guard now.timeIntervalSinceReferenceDate.isFinite, window.start > now else {
            throw WindowValidationError.startNotInFuture
        }

        var saved = window
        if let index = state.windows.firstIndex(where: { $0.id == window.id }) {
            let revision = state.windows[index].revision
            guard revision < Int.max else { throw WindowValidationError.exhaustedRevision }
            saved.revision = revision + 1
            state.windows[index] = saved
        } else {
            // A cancelled occurrence may still own a close. Never reuse that close's token.
            if let retainedRevision = state.sessions.lazy.filter({ $0.windowID == window.id }).map(\.revision).max() {
                guard retainedRevision < Int.max else { throw WindowValidationError.exhaustedRevision }
                saved.revision = max(window.revision, retainedRevision + 1)
            }
            state.windows.append(saved)
        }
        state.confirmedRevisions.removeValue(forKey: window.id.uuidString)
    }

    public static func cancel(windowID: UUID, in state: inout CallState) {
        state.windows.removeAll { $0.id == windowID }
        state.confirmedRevisions.removeValue(forKey: windowID.uuidString)
        // An allow decision owns restoration even though it cannot prove that Shortcuts changed the setting.
    }

    public static func confirmSetup(windowID: UUID, in state: inout CallState) {
        guard let window = state.windows.first(where: { $0.id == windowID }) else { return }
        state.confirmedRevisions[windowID.uuidString] = window.revision
    }

    public static func evaluate(
        boundary: CallBoundary,
        windowID: UUID,
        revision: Int,
        now: Date,
        state: inout CallState
    ) -> CallDecision {
        guard now.timeIntervalSinceReferenceDate.isFinite else {
            return record(.noChange, "The current date is invalid.", in: &state)
        }
        switch boundary {
        case .opening:
            return open(windowID: windowID, revision: revision, now: now, state: &state)
        case .closing:
            return close(windowID: windowID, revision: revision, now: now, state: &state)
        }
    }

    static func validate(_ window: ExpectedCallWindow) throws {
        guard window.start.timeIntervalSinceReferenceDate.isFinite,
              window.end.timeIntervalSinceReferenceDate.isFinite,
              window.start < window.end else { throw WindowValidationError.invalidRange }
        guard TimeZone(identifier: window.timeZoneIdentifier) != nil else {
            throw WindowValidationError.invalidTimeZone
        }
        guard window.revision > 0 else { throw WindowValidationError.invalidRevision }
    }

    private static func open(
        windowID: UUID, revision: Int, now: Date, state: inout CallState
    ) -> CallDecision {
        guard let window = state.windows.first(where: { $0.id == windowID && $0.revision == revision }) else {
            return record(.noChange, "Opening ignored: this occurrence or revision is no longer scheduled.", in: &state)
        }
        guard state.confirmedRevisions[windowID.uuidString] == revision else {
            return record(.noChange, "Opening ignored: setup has not been confirmed for this revision.", in: &state)
        }
        guard window.start <= now, now < window.end else {
            return record(.noChange, "Opening ignored: the current date is outside this occurrence's window.", in: &state)
        }
        guard !state.sessions.contains(where: { $0.windowID == windowID }) else {
            return record(.noChange, "Opening ignored: this occurrence already has a retained closing responsibility.", in: &state)
        }
        state.sessions.append(CallSession(windowID: windowID, revision: revision, end: window.end))
        return record(.allow, "Allow requested. Shortcuts must turn Silence unknown callers off; ringing is not guaranteed.", in: &state)
    }

    private static func close(
        windowID: UUID, revision: Int, now: Date, state: inout CallState
    ) -> CallDecision {
        guard let session = state.sessions.first(where: { $0.windowID == windowID && $0.revision == revision }) else {
            return record(.noChange, "Closing ignored: this automation does not own a pending restoration.", in: &state)
        }
        guard now >= session.end else {
            return record(.noChange, "Closing ignored: the retained occurrence has not ended yet.", in: &state)
        }

        // A valid late close may recover every expired responsibility, but a stale token cannot.
        state.sessions.removeAll { $0.end <= now }
        for window in state.windows where window.start <= now && now < window.end {
            guard state.confirmedRevisions[window.id.uuidString] == window.revision,
                  !state.sessions.contains(where: { $0.windowID == window.id && $0.revision == window.revision }) else {
                continue
            }
            // Its opening may have been missed. Transfer responsibility so its own close can restore.
            state.sessions.append(CallSession(windowID: window.id, revision: window.revision, end: window.end))
        }
        guard state.sessions.isEmpty else {
            return record(.noChange, "Closing retained allowance: another occurrence still owns a future restoration.", in: &state)
        }
        return record(.restoreSilence, "Restore Silence unknown callers requested. Shortcuts must turn it on.", in: &state)
    }

    private static func record(_ decision: CallDecision, _ message: String, in state: inout CallState) -> CallDecision {
        state.lastEvaluation = message
        return decision
    }
}
