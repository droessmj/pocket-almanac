import XCTest
@testable import HabitKit

final class HabitKitTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "America/Chicago")!
        return value
    }

    private func date(_ day: Int, month: Int = 3, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private func habit(kind: HabitKind = .progress) -> Habit {
        Habit(name: "Walk", emoji: "🚶", color: .blue, kind: kind, target: 100, step: 10,
              unit: "steps", createdAt: date(1))
    }

    func testPassFailAndMissingAreDistinct() {
        let habit = habit(kind: .checkIn)
        var archive = HabitArchive(habits: [habit])
        XCTAssertNil(archive.entry(for: habit, on: date(4), calendar: calendar))
        archive.record(habit, on: date(4), checkIn: .failed, calendar: calendar)
        XCTAssertEqual(archive.entry(for: habit, on: date(4), calendar: calendar)?.checkIn, .failed)
        XCTAssertFalse(archive.isComplete(habit, on: date(4), calendar: calendar))
        archive.record(habit, on: date(4), checkIn: .passed, calendar: calendar)
        XCTAssertTrue(archive.isComplete(habit, on: date(4), calendar: calendar))
        XCTAssertEqual(archive.entries.count, 1)
        archive.clear(habit, on: date(4), calendar: calendar)
        XCTAssertTrue(archive.entries.isEmpty)
    }

    func testProgressAccumulatesAndCanExceedGoal() {
        let habit = habit()
        var archive = HabitArchive(habits: [habit])
        for _ in 0..<12 {
            let current = archive.entry(for: habit, on: date(5), calendar: calendar)?.value ?? 0
            archive.record(habit, on: date(5), value: current + habit.step, calendar: calendar)
        }
        let entry = archive.entry(for: habit, on: date(5), calendar: calendar)!
        XCTAssertEqual(entry.value, 120)
        XCTAssertEqual(entry.fraction, 1)
        XCTAssertTrue(entry.isComplete)
        XCTAssertEqual(archive.entries.count, 1)
    }

    func testEditingGoalPreservesHistoricalResult() {
        var habit = habit()
        var archive = HabitArchive(habits: [habit])
        archive.record(habit, on: date(5), value: 100, calendar: calendar)
        habit.target = 200
        archive.habits[0] = habit
        archive.record(habit, on: date(5), value: 110, calendar: calendar)
        archive.record(habit, on: date(6), value: 110, calendar: calendar)
        XCTAssertEqual(archive.entry(for: habit, on: date(5), calendar: calendar)?.target, 100)
        XCTAssertTrue(archive.isComplete(habit, on: date(5), calendar: calendar))
        XCTAssertFalse(archive.isComplete(habit, on: date(6), calendar: calendar))
    }

    func testRejectsInvalidValuesAndOutOfRangeDates() {
        let habit = habit()
        var archive = HabitArchive(habits: [habit])
        for invalid in [-1, Double.nan, .infinity] {
            archive.record(habit, on: date(5), value: invalid, calendar: calendar)
        }
        archive.record(habit, on: date(1, month: 2), value: 30, calendar: calendar)
        archive.record(habit, on: date(7), value: 30, calendar: calendar, now: date(6))
        XCTAssertTrue(archive.entries.isEmpty)
        archive.record(habit, on: date(5), value: 0, calendar: calendar)
        XCTAssertEqual(archive.entries.count, 1)
    }

    func testDayKeysAndSamplesAcrossDaylightSaving() {
        let habit = habit()
        var archive = HabitArchive(habits: [habit])
        archive.record(habit, on: date(8, hour: 1), value: 50, calendar: calendar)
        XCTAssertEqual(archive.entry(for: habit, on: date(8, hour: 23), calendar: calendar)?.value, 50)
        let samples = archive.samples(for: habit, days: 4, through: date(10), calendar: calendar)
        XCTAssertEqual(samples.map { calendar.component(.day, from: $0.date) }, [7, 8, 9, 10])
        XCTAssertEqual(samples.map(\.fraction), [0, 0.5, 0, 0])
    }

    func testTrendExcludesDaysBeforeCreation() {
        let habit = habit()
        let archive = HabitArchive(habits: [habit])
        XCTAssertEqual(archive.samples(for: habit, days: 30, through: date(3), calendar: calendar).count, 3)
        XCTAssertTrue(archive.samples(for: habit, days: 0, calendar: calendar).isEmpty)
    }

    func testStreakStopsAtFailureAndMissingDay() {
        let habit = habit(kind: .checkIn)
        var archive = HabitArchive(habits: [habit])
        archive.record(habit, on: date(5), checkIn: .failed, calendar: calendar)
        archive.record(habit, on: date(6), checkIn: .passed, calendar: calendar)
        archive.record(habit, on: date(7), checkIn: .passed, calendar: calendar)
        XCTAssertEqual(archive.streak(for: habit, through: date(7), calendar: calendar), 2)
        XCTAssertEqual(archive.streak(for: habit, through: date(8), calendar: calendar), 0)
    }

    func testUnfinishedTodayPreservesYesterdayStreak() {
        let now = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let habit = Habit(name: "Read", emoji: "📚", color: .rose, kind: .checkIn, createdAt: yesterday)
        var archive = HabitArchive(habits: [habit])
        archive.record(habit, on: yesterday, checkIn: .passed, calendar: calendar)
        XCTAssertEqual(archive.streak(for: habit, through: now, calendar: calendar), 1)
        archive.record(habit, on: now, checkIn: .passed, calendar: calendar)
        XCTAssertEqual(archive.streak(for: habit, through: now, calendar: calendar), 2)
    }

    func testIndependentHabitsAndCalendarDays() {
        let one = habit()
        let two = habit()
        var archive = HabitArchive(habits: [one, two])
        archive.record(one, on: date(5), value: 100, calendar: calendar)
        archive.record(two, on: date(5), value: 20, calendar: calendar)
        archive.record(one, on: date(6), value: 50, calendar: calendar)
        XCTAssertTrue(archive.isComplete(one, on: date(5), calendar: calendar))
        XCTAssertFalse(archive.isComplete(two, on: date(5), calendar: calendar))
        XCTAssertEqual(archive.entry(for: one, on: date(6), calendar: calendar)?.value, 50)
    }

    func testArchiveRoundTripIncludingArchivedHabits() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = ArchiveFile(url: directory.appendingPathComponent("habits.json"))
        XCTAssertNil(try file.load())
        var habit = habit(kind: .checkIn)
        habit.isArchived = true
        var archive = HabitArchive(habits: [habit])
        archive.record(habit, on: date(5), checkIn: .failed, calendar: calendar)
        try file.save(archive)
        XCTAssertEqual(try file.load(), archive)
        try file.save(HabitArchive())
        XCTAssertEqual(try file.load(), HabitArchive())
    }

    func testCorruptAndUnsupportedArchivesAreNotSilentlyReset() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = ArchiveFile(url: directory.appendingPathComponent("habits.json"))
        var archive = HabitArchive()
        archive.version = 99
        try file.save(archive)
        XCTAssertThrowsError(try file.load())
        try Data("broken".utf8).write(to: file.url)
        XCTAssertThrowsError(try file.load())
        XCTAssertEqual(try String(contentsOf: file.url, encoding: .utf8), "broken")
    }
}
