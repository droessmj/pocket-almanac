import Foundation

public struct CallStore: Sendable {
    public let url: URL

    // Also serialize callers inside this process; NSFileCoordinator handles coordinated external access.
    private static let processLock = NSLock()

    public init(url: URL) {
        self.url = url
    }

    public static var defaultURL: URL {
        URL.applicationSupportDirectory
            .appendingPathComponent("ExpectedCalls", isDirectory: true)
            .appendingPathComponent("state.json", isDirectory: false)
    }

    public func load() throws -> CallState {
        try coordinate { coordinatedURL in
            if let state = try readExisting(at: coordinatedURL) { return state }
            let state = CallState.initial
            try write(state, to: coordinatedURL)
            return state
        }
    }

    public func update<T>(_ body: (inout CallState) throws -> T) throws -> T {
        try coordinate { coordinatedURL in
            var state = try readExisting(at: coordinatedURL) ?? .initial
            let result = try body(&state)
            try write(state, to: coordinatedURL)
            return result
        }
    }

    private func coordinate<T>(_ body: (URL) throws -> T) throws -> T {
        Self.processLock.lock()
        defer { Self.processLock.unlock() }

        let directory = url.deletingLastPathComponent()
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        #if os(iOS)
        try manager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: directory.path
        )
        #endif

        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinationError: NSError?
        var result: Result<T, Error>?
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { coordinatedURL in
            result = Result { try body(coordinatedURL) }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw CallStoreError.coordinationFailed }
        return try result.get()
    }

    private func readExisting(at url: URL) throws -> CallState? {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch let readError as CocoaError where readError.code == .fileReadNoSuchFile {
            // A dangling symlink is an existing, unreadable entry, not an absent store.
            do {
                _ = try FileManager.default.attributesOfItem(atPath: url.path)
            } catch let attributesError as CocoaError where attributesError.code == .fileReadNoSuchFile {
                return nil
            }
            throw readError
        }
        #if os(iOS)
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
        #endif
        let state = try JSONDecoder().decode(StorageEnvelope.self, from: data).state
        try Self.validate(state)
        return state
    }

    private func write(_ state: CallState, to url: URL) throws {
        try Self.validate(state)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(StorageEnvelope(state: state))
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        #else
        try data.write(to: url, options: .atomic)
        #endif
    }

    private static func validate(_ state: CallState) throws {
        guard Set(state.windows.lazy.map(\.id)).count == state.windows.count else {
            throw CallStoreError.invalidState
        }
        for window in state.windows {
            try WindowEngine.validate(window)
        }
        for (id, revision) in state.confirmedRevisions {
            guard let window = state.windows.first(where: { $0.id.uuidString == id }),
                  window.revision == revision else { throw CallStoreError.invalidState }
        }
        var sessionTokens = Set<SessionToken>()
        for session in state.sessions {
            let token = SessionToken(windowID: session.windowID, revision: session.revision)
            guard session.revision > 0, session.end.timeIntervalSinceReferenceDate.isFinite,
                  sessionTokens.insert(token).inserted else { throw CallStoreError.invalidState }
        }
    }
}

private struct SessionToken: Hashable {
    let windowID: UUID
    let revision: Int
}

private struct StorageEnvelope: Codable {
    let version: Int
    let state: CallState

    init(state: CallState) {
        version = 1
        self.state = state
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case state
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        guard version == 1 else { throw CallStoreError.unsupportedVersion(version) }
        state = try container.decode(CallState.self, forKey: .state)
    }
}

public enum CallStoreError: LocalizedError, Equatable {
    case unsupportedVersion(Int)
    case invalidState
    case coordinationFailed

    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            "Stored data version \(version) is not supported. Existing data was not reset."
        case .invalidState:
            "Stored call data is inconsistent. Existing data was not reset."
        case .coordinationFailed:
            "The call data file could not be coordinated. Try again before relying on the automation."
        }
    }
}
