import AppIntents
import Foundation
import ExpectedCallsCore

enum ExpectedCallBoundary: String, AppEnum {
    case opening
    case closing

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Call boundary" }
    static var caseDisplayRepresentations: [ExpectedCallBoundary: DisplayRepresentation] {
        [.opening: "Opening", .closing: "Closing"]
    }

    var coreBoundary: CallBoundary {
        switch self {
        case .opening: .opening
        case .closing: .closing
        }
    }
}

struct EvaluateExpectedCallsIntent: AppIntent {
    static var title: LocalizedStringResource { "Evaluate Expected Calls" }
    static var description: IntentDescription {
        IntentDescription("Evaluates a saved expected-call boundary and returns allow, restoreSilence, or noChange. Add your own conditional Phone-setting actions after this intent. It does not change a Phone setting or verify that a subsequent action succeeded.")
    }
    static var openAppWhenRun: Bool { false }

    @Parameter(title: "Boundary")
    var boundary: ExpectedCallBoundary

    @Parameter(title: "Window ID")
    var windowID: String

    @Parameter(title: "Revision")
    var revision: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Evaluate \(\.$boundary) for \(\.$windowID), revision \(\.$revision)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let store = CallStore(url: CallStore.defaultURL)
        let decision: CallDecision
        do {
            guard let id = UUID(uuidString: windowID.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                recordFailure("Window ID is not a valid UUID.", in: store)
                return .result(value: CallDecision.noChange.rawValue)
            }
            decision = try store.update { state in
                WindowEngine.evaluate(boundary: boundary.coreBoundary, windowID: id, revision: revision, now: .now, state: &state)
            }
        } catch {
            recordFailure(error.localizedDescription, in: store)
            return .result(value: CallDecision.noChange.rawValue)
        }
        return .result(value: decision.rawValue)
    }

    private func recordFailure(_ message: String, in store: CallStore) {
        // A corrupt or inaccessible store must stay untouched; the app exposes load errors.
        // When readable, persist the diagnostic so the next foreground refresh can show it.
        do {
            try store.update { state in
                state.lastEvaluation = "\(Date.now.formatted(.iso8601)) · noChange · \(boundary.rawValue) · Window \(windowID), revision \(revision): \(message) No Phone-setting change was requested."
            }
        } catch {
            // Returning noChange is fail-closed. Do not replace unreadable state to log an error.
        }
    }
}
