import Foundation

public struct ExpectedCallWindow: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var label: String
    public var start: Date
    public var end: Date
    public var timeZoneIdentifier: String
    public var revision: Int

    public init(
        id: UUID = UUID(),
        label: String = "Expected call",
        start: Date,
        end: Date,
        timeZoneIdentifier: String = "America/Chicago",
        revision: Int = 1
    ) {
        self.id = id
        self.label = label
        self.start = start
        self.end = end
        self.timeZoneIdentifier = timeZoneIdentifier
        self.revision = revision
    }
}

public struct CallSession: Codable, Equatable, Sendable {
    public var windowID: UUID
    public var revision: Int
    public var end: Date

    public init(windowID: UUID, revision: Int, end: Date) {
        self.windowID = windowID
        self.revision = revision
        self.end = end
    }
}

public struct CallState: Codable, Equatable, Sendable {
    public var windows: [ExpectedCallWindow]
    public var confirmedRevisions: [String: Int]
    public var sessions: [CallSession]
    public var lastEvaluation: String?

    public init(
        windows: [ExpectedCallWindow] = [],
        confirmedRevisions: [String: Int] = [:],
        sessions: [CallSession] = [],
        lastEvaluation: String? = nil
    ) {
        self.windows = windows
        self.confirmedRevisions = confirmedRevisions
        self.sessions = sessions
        self.lastEvaluation = lastEvaluation
    }

    public static let initial: CallState = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        // November 4 is CST (UTC−6), so 15:55–16:15 Chicago is 21:55–22:15 UTC.
        let start = calendar.date(from: DateComponents(year: 2026, month: 11, day: 4, hour: 21, minute: 55))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 11, day: 4, hour: 22, minute: 15))!
        return CallState(windows: [ExpectedCallWindow(start: start, end: end)])
    }()
}

public enum CallDecision: String, Codable, Sendable {
    case allow
    case restoreSilence
    case noChange
}

public enum CallBoundary: String, Sendable {
    case opening
    case closing
}

public enum WindowValidationError: LocalizedError, Equatable {
    case invalidRange
    case startNotInFuture
    case invalidTimeZone
    case invalidRevision
    case exhaustedRevision

    public var errorDescription: String? {
        switch self {
        case .invalidRange:
            "The end must be later than the start, and both dates must be finite."
        case .startNotInFuture:
            "Choose a start in the future before saving this occurrence."
        case .invalidTimeZone:
            "Choose a recognized time zone."
        case .invalidRevision:
            "This occurrence has an invalid revision."
        case .exhaustedRevision:
            "This occurrence cannot be edited again. Create a new occurrence instead."
        }
    }
}
