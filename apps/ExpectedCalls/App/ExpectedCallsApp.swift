import SwiftUI
import Observation
import ExpectedCallsCore

@main
struct ExpectedCallsApp: App {
    @State private var model = ExpectedCallsModel()

    var body: some Scene {
        WindowGroup {
            ExpectedCallsView()
                .environment(model)
                .tint(.indigo)
        }
    }
}

@MainActor
@Observable
final class ExpectedCallsModel {
    private let store: CallStore
    private(set) var state: CallState?
    var errorMessage: String?

    init() {
        var storeURL = CallStore.defaultURL
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--expected-calls-ui-testing") {
            storeURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("ExpectedCallsUITesting", isDirectory: true)
                .appendingPathComponent("state.json")
            if arguments.contains("--expected-calls-reset-ui-testing") {
                do {
                    if FileManager.default.fileExists(atPath: storeURL.path) {
                        try FileManager.default.removeItem(at: storeURL)
                    }
                } catch {
                    store = CallStore(url: storeURL)
                    errorMessage = "Couldn’t reset isolated UI-test data. \(error.localizedDescription)"
                    return
                }
            }
        }
        #endif
        store = CallStore(url: storeURL)
        reload()
    }

    func reload() {
        do {
            state = try store.load()
        } catch {
            state = nil
            errorMessage = "Couldn’t read your local data. It has not been replaced. \(error.localizedDescription)"
        }
    }

    @discardableResult
    func save(_ window: ExpectedCallWindow) -> Bool {
        mutate { state in
            try WindowEngine.save(window, in: &state, now: .now)
        }
    }

    func cancel(windowID: UUID) {
        mutate { state in WindowEngine.cancel(windowID: windowID, in: &state) }
    }

    func confirmSetup(windowID: UUID) {
        mutate { state in WindowEngine.confirmSetup(windowID: windowID, in: &state) }
    }

    @discardableResult
    private func mutate(_ change: (inout CallState) throws -> Void) -> Bool {
        do {
            state = try store.update { state in
                try change(&state)
                return state
            }
            return true
        } catch {
            errorMessage = "Your change could not be saved. \(error.localizedDescription)"
            return false
        }
    }
}

enum CallTime {
    static let chicago = TimeZone(identifier: "America/Chicago")!

    static func instant(_ date: Date, in zone: TimeZone = chicago) -> String {
        let style = Date.FormatStyle(
            date: .abbreviated, time: .shortened,
            locale: Locale(identifier: "en_US_POSIX"), timeZone: zone
        )
        let offset = zone.secondsFromGMT(for: date)
        let magnitude = abs(offset)
        let numericOffset = String(format: "UTC%@%02d:%02d", offset < 0 ? "-" : "+", magnitude / 3600, (magnitude % 3600) / 60)
        return "\(date.formatted(style)) \(numericOffset)"
    }

    static func trigger(_ date: Date, in zone: TimeZone) -> String {
        date.formatted(Date.FormatStyle(
            date: .omitted, time: .shortened,
            locale: Locale(identifier: "en_US_POSIX"), timeZone: zone
        ))
    }
}
