import Foundation
import HabitKit
import Observation

@Observable @MainActor
final class HabitStore {
    private(set) var archive = HabitArchive()
    private(set) var ready = false
    private(set) var needsLegacyCalendar = false
    var errorMessage: String?
    private let file: ArchiveFile

    init() {
        var directory = URL.applicationSupportDirectory.appendingPathComponent("DayInInk", isDirectory: true)
        #if DEBUG
        if let testID = ProcessInfo.processInfo.environment["DAYININK_TEST_STORE"], UUID(uuidString: testID) != nil {
            directory = URL.temporaryDirectory.appendingPathComponent("DayInInkTests-\(testID)", isDirectory: true)
        }
        #endif
        file = ArchiveFile(url: directory.appendingPathComponent("habits.json"))
        load()
    }

    var activeHabits: [Habit] { archive.habits.filter { !$0.isArchived } }

    /// Called only after the user confirms replacement of all data. Publish in memory after saving.
    func restore(_ imported: HabitArchive) throws {
        try file.save(imported)
        archive = imported
        ready = true
        errorMessage = nil
    }

    func load() {
        needsLegacyCalendar = false
        do {
            if let saved = try file.load() {
                archive = saved
            } else {
                let initial = HabitArchive.starterHabits()
                try file.save(initial)
                archive = initial
            }
            ready = true
        } catch ArchiveValidationError.legacyCalendarRequired {
            ready = false
            needsLegacyCalendar = true
            errorMessage = nil
        } catch {
            ready = false
            errorMessage = "Your habits couldn’t be opened. Your saved file has been kept. \(error.localizedDescription)"
        }
    }

    /// Old archives did not record their calendar. Convert only after the user identifies it.
    func migrateLegacyArchive(using calendar: Calendar) {
        do {
            guard let saved = try file.load(legacyCalendar: calendar) else {
                load()
                return
            }
            try file.save(saved)
            archive = saved
            ready = true
            needsLegacyCalendar = false
            errorMessage = nil
        } catch {
            errorMessage = "Your saved file has been kept. \(error.localizedDescription)"
        }
    }

    @discardableResult
    private func commit(_ change: (inout HabitArchive) -> Void) -> Bool {
        guard ready else { return false }
        var updated = archive
        change(&updated)
        do {
            try file.save(updated)
            archive = updated
            return true
        } catch {
            errorMessage = "Your change couldn’t be saved. Please try again. \(error.localizedDescription)"
            return false
        }
    }

    @discardableResult
    func save(_ habit: Habit) -> Bool {
        guard habit.isValid else { return false }
        return commit { archive in
            if let index = archive.habits.firstIndex(where: { $0.id == habit.id }) {
                archive.habits[index] = habit
            } else {
                archive.habits.append(habit)
            }
        }
    }

    func entry(_ habit: Habit, on date: Date) -> HabitEntry? { archive.effectiveEntry(for: habit, on: date) }

    @discardableResult
    func record(_ habit: Habit, on date: Date, value: Double? = nil, checkIn: CheckIn? = nil) -> Bool {
        commit { $0.record(habit, on: date, value: value, checkIn: checkIn) }
    }

    @discardableResult
    func clear(_ habit: Habit, on date: Date) -> Bool {
        commit { $0.clear(habit, on: date) }
    }

    func quickLog(_ habit: Habit, on date: Date) {
        let existing = entry(habit, on: date)
        if (existing?.kind ?? habit.kind) == .checkIn {
            if existing?.checkIn == .passed { _ = record(habit, on: date, checkIn: .failed) }
            else { _ = record(habit, on: date, checkIn: .passed) }
        } else {
            _ = record(habit, on: date, value: (existing?.value ?? 0) + habit.step)
        }
    }

    func archiveHabit(_ habit: Habit) {
        var updated = habit
        updated.isArchived.toggle()
        save(updated)
    }

    @discardableResult
    func delete(_ habit: Habit) -> Bool {
        commit {
            $0.habits.removeAll { $0.id == habit.id }
            $0.entries.removeAll { $0.habitID == habit.id }
        }
    }
}
