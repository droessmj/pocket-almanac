import Foundation
import HabitKit
import Observation

@Observable @MainActor
final class HabitStore {
    private(set) var archive = HabitArchive()
    private(set) var ready = false
    private(set) var isLoading = true
    var errorMessage: String?
    private let file: ArchiveFile
    @ObservationIgnored private var pendingOperation: Task<Void, Never>?

    init(file: ArchiveFile? = nil) {
        if let file {
            self.file = file
        } else {
            var directory = URL.applicationSupportDirectory.appendingPathComponent("DayInInk", isDirectory: true)
            #if DEBUG
            if let testID = ProcessInfo.processInfo.environment["DAYININK_TEST_STORE"], UUID(uuidString: testID) != nil {
                directory = URL.temporaryDirectory.appendingPathComponent("DayInInkTests-\(testID)", isDirectory: true)
            }
            #endif
            self.file = ArchiveFile(url: directory.appendingPathComponent("habits.json"))
        }
        pendingOperation = Task { await readFromDisk() }
    }

    var activeHabits: [Habit] { archive.habits.filter { !$0.isArchived } }

    // Queue reads and writes in submission order. Each edit starts from the last successfully
    // published archive, not a snapshot captured before an earlier save finishes.
    private func perform<T: Sendable>(_ operation: @escaping @MainActor () async throws -> T) async throws -> T {
        let previous = pendingOperation
        let task = Task { @MainActor in
            await previous?.value
            return try await operation()
        }
        pendingOperation = Task {
            // This barrier carries ordering only; the caller receives the actual result/error.
            _ = await task.result
        }
        return try await task.value
    }

    func load() async {
        do {
            try await perform { await self.readFromDisk() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func readFromDisk() async {
        isLoading = true
        defer { isLoading = false }
        let file = file
        do {
            let saved = try await Task.detached(priority: .userInitiated) {
                if let saved = try file.load() { return saved }
                let initial = HabitArchive.starterHabits()
                try file.save(initial)
                return initial
            }.value
            archive = saved
            ready = true
            errorMessage = nil
        } catch {
            ready = false
            errorMessage = "Your habits couldn’t be opened. Your saved file has been kept. \(error.localizedDescription)"
        }
    }

    func snapshot() async throws -> HabitArchive {
        try await perform {
            guard self.ready else { throw HabitStoreError.notReady }
            return self.archive
        }
    }

    /// Publish only after atomic persistence succeeds. Failed changes never replace memory or disk.
    private func commit(_ change: @escaping (inout HabitArchive) throws -> Void) async throws {
        try await perform {
            guard self.ready else { throw HabitStoreError.notReady }
            var updated = self.archive
            try change(&updated)
            let snapshot = updated
            let file = self.file
            try await Task.detached(priority: .userInitiated) { try file.save(snapshot) }.value
            self.archive = updated
        }
    }

    /// Called only after confirmation. Recovery imports also work when the current file won't load.
    func restore(_ imported: HabitArchive) async throws {
        try await perform {
            let file = self.file
            try await Task.detached(priority: .userInitiated) { try file.save(imported) }.value
            self.archive = imported
            self.ready = true
            self.errorMessage = nil
        }
    }

    func save(_ habit: Habit) async throws {
        guard habit.isValid else { throw ArchiveValidationError.invalidData }
        try await commit { archive in
            if let index = archive.habits.firstIndex(where: { $0.id == habit.id }) {
                archive.habits[index] = habit
            } else {
                archive.habits.append(habit)
            }
        }
    }

    func entry(_ habit: Habit, on date: Date) -> HabitEntry? { archive.effectiveEntry(for: habit, on: date) }

    func record(_ habit: Habit, on date: Date, value: Decimal? = nil, checkIn: CheckIn? = nil) async throws {
        let calendar = Calendar.current
        try await commit { archive in
            guard archive.record(habit, on: date, value: value, checkIn: checkIn, calendar: calendar) else {
                throw HabitStoreError.invalidRecord
            }
        }
    }

    func clear(_ habit: Habit, on date: Date) async throws {
        let calendar = Calendar.current
        try await commit { archive in
            guard archive.entry(for: habit, on: date, calendar: calendar) != nil else { throw HabitStoreError.invalidRecord }
            archive.clear(habit, on: date, calendar: calendar)
        }
    }

    func quickLog(_ habit: Habit, on date: Date) async throws {
        let calendar = Calendar.current
        try await commit { archive in
            guard let current = archive.habits.first(where: { $0.id == habit.id }) else {
                throw HabitStoreError.missingHabit
            }
            let existing = archive.effectiveEntry(for: current, on: date, calendar: calendar)
            let recorded: Bool
            if (existing?.kind ?? current.kind) == .checkIn {
                recorded = archive.record(current, on: date, checkIn: existing?.checkIn == .passed ? .failed : .passed,
                                          calendar: calendar)
            } else {
                let total = try HabitAmount.adding(existing?.value ?? 0, current.step)
                recorded = archive.record(current, on: date, value: total, calendar: calendar)
            }
            guard recorded else { throw HabitStoreError.invalidRecord }
        }
    }

    func archiveHabit(_ habit: Habit) async throws {
        let archived = !habit.isArchived
        try await commit { archive in
            guard let index = archive.habits.firstIndex(where: { $0.id == habit.id }) else {
                throw HabitStoreError.missingHabit
            }
            archive.habits[index].isArchived = archived
        }
    }

    func delete(_ habit: Habit) async throws {
        try await commit { archive in
            guard archive.habits.contains(where: { $0.id == habit.id }) else { throw HabitStoreError.missingHabit }
            archive.habits.removeAll { $0.id == habit.id }
            archive.entries.removeAll { $0.habitID == habit.id }
        }
    }
}

private enum HabitStoreError: LocalizedError {
    case notReady, invalidRecord, missingHabit

    var errorDescription: String? {
        switch self {
        case .notReady: "Your habits aren’t available yet. Try opening them again."
        case .invalidRecord: "This check-in couldn’t be saved. Choose a day from the habit’s start date through today and enter a valid result."
        case .missingHabit: "This habit is no longer available."
        }
    }
}
