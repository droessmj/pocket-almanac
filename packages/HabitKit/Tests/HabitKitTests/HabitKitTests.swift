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
              unit: "steps", createdAt: date(1), calendar: calendar)
    }

    func testStarterHabitsHaveOnlyTheRequestedNamesGoalsAndTracking() throws {
        let archive = HabitArchive.starterHabits(now: date(1))
        XCTAssertEqual(archive.habits.count, 3)
        XCTAssertEqual(Set(archive.habits.map(\.name)), ["Walk", "Drink Water", "Workout"])
        let walk = try XCTUnwrap(archive.habits.first { $0.name == "Walk" })
        XCTAssertEqual(walk.kind, .progress)
        XCTAssertEqual(walk.target, 10_000)
        XCTAssertEqual(walk.unit, "steps")
        let water = try XCTUnwrap(archive.habits.first { $0.name == "Drink Water" })
        XCTAssertEqual(water.kind, .progress)
        XCTAssertEqual(water.target, 8)
        XCTAssertEqual(water.unit, "glasses")
        let workout = try XCTUnwrap(archive.habits.first { $0.name == "Workout" })
        XCTAssertEqual(workout.kind, .checkIn)
    }

    func testQuickAddArithmeticRejectsPrecisionLossAndOverflow() throws {
        let tiny = try XCTUnwrap(Decimal(string: "1e-120"))
        let huge = try XCTUnwrap(Decimal(string: "1e120"))
        XCTAssertThrowsError(try HabitAmount.adding(huge, tiny))
        XCTAssertThrowsError(try HabitAmount.multiplying(NSDecimalNumber.maximum.decimalValue, by: 5))
        XCTAssertThrowsError(try HabitAmount.adding(.nan, 1))
        let step = try XCTUnwrap(Decimal(string: "0.1"))
        var total: Decimal = 0
        for _ in 0..<10 { total = try HabitAmount.adding(total, step) }
        XCTAssertEqual(total, 1)
        XCTAssertEqual(try HabitAmount.multiplying(step, by: 5), Decimal(string: "0.5"))
    }

    func testRecordUsesCurrentHabitSettingsButKeepsRecordedSnapshots() throws {
        let original = habit()
        var archive = HabitArchive(habits: [original])
        XCTAssertTrue(archive.record(original, on: date(2), value: 100, calendar: calendar))
        var edited = original
        edited.target = 200
        edited.unit = "meters"
        archive.habits[0] = edited
        XCTAssertTrue(archive.record(original, on: date(3), value: 150, calendar: calendar))
        let newEntry = try XCTUnwrap(archive.entry(for: edited, on: date(3), calendar: calendar))
        XCTAssertEqual(newEntry.target, 200)
        XCTAssertEqual(newEntry.unit, "meters")
        XCTAssertFalse(newEntry.isComplete)
        XCTAssertTrue(archive.record(original, on: date(2), value: 110, calendar: calendar))
        let historical = try XCTUnwrap(archive.entry(for: edited, on: date(2), calendar: calendar))
        XCTAssertEqual(historical.target, 100)
        XCTAssertEqual(historical.unit, "steps")
        edited.kind = .checkIn
        archive.habits[0] = edited
        XCTAssertFalse(archive.record(original, on: date(4), value: 100, calendar: calendar))
        XCTAssertTrue(archive.record(original, on: date(4), checkIn: .passed, calendar: calendar))
        XCTAssertEqual(archive.entry(for: edited, on: date(4), calendar: calendar)?.kind, .checkIn)
    }

    func testChartFractionDoesNotOverflowOrUnderflowDecimalDivision() throws {
        let tiny = try XCTUnwrap(Decimal(string: "1e-120"))
        let huge = try XCTUnwrap(Decimal(string: "1e120"))
        let habit = Habit(name: "Extreme", emoji: "💧", color: .mint, kind: .progress,
                          target: huge, step: tiny, createdAt: date(1), calendar: calendar)
        var entry = HabitEntry(habit: habit, date: date(2), value: tiny, calendar: calendar)
        XCTAssertTrue(entry.fraction.isFinite)
        XCTAssertGreaterThan(entry.fraction, 0)
        XCTAssertEqual(entry.fraction / 1e-240, 1, accuracy: 0.000000001)
        entry.target = tiny
        entry.value = huge
        XCTAssertEqual(entry.fraction, 1)
        XCTAssertTrue(entry.isComplete)
    }

    func testDecimalStepsReachGoalExactlyAndRoundTripTinyAmounts() throws {
        for amount in ["0.1", "0.00000000000000000001"] {
            let step = try XCTUnwrap(Decimal(string: amount))
            let habit = Habit(name: "Measure", emoji: "💧", color: .mint, kind: .progress,
                              target: step * 10, step: step, createdAt: date(1), calendar: calendar)
            var archive = HabitArchive(habits: [habit])
            for count in 1...10 {
                let current = archive.entry(for: habit, on: date(2), calendar: calendar)?.value ?? 0
                XCTAssertTrue(archive.record(habit, on: date(2), value: current + step, calendar: calendar))
                let entry = try XCTUnwrap(archive.entry(for: habit, on: date(2), calendar: calendar))
                XCTAssertEqual(entry.value, step * Decimal(count))
                XCTAssertEqual(entry.isComplete, count == 10)
                XCTAssertEqual(entry.fraction, Double(count) / 10, accuracy: 0.000000001)
            }
            let restored = try ArchiveFile.decode(ArchiveFile.encode(archive))
            XCTAssertEqual(restored, archive)
            XCTAssertEqual(restored.habits[0].step, step)
            XCTAssertEqual(restored.entries[0].value, habit.target)
            XCTAssertTrue(restored.isComplete(habit, on: date(2), calendar: calendar))
        }
    }

    func testRecordReportsRejectionWithoutChangingHistory() throws {
        let progress = habit()
        let checkIn = habit(kind: .checkIn)
        let absent = habit()
        var archive = HabitArchive(habits: [progress, checkIn])
        XCTAssertFalse(archive.record(progress, on: date(2), calendar: calendar))
        XCTAssertFalse(archive.record(progress, on: date(2), checkIn: .passed, calendar: calendar))
        XCTAssertFalse(archive.record(progress, on: date(2), value: 1, checkIn: .passed, calendar: calendar))
        XCTAssertFalse(archive.record(checkIn, on: date(2), value: 1, calendar: calendar))
        XCTAssertFalse(archive.record(absent, on: date(2), value: 1, calendar: calendar))
        XCTAssertFalse(archive.record(progress, on: Date(timeIntervalSinceReferenceDate: .infinity),
                                      value: 1, calendar: calendar))
        XCTAssertFalse(archive.record(progress, on: date(2), value: 1, calendar: calendar,
                                      now: Date(timeIntervalSinceReferenceDate: .nan)))
        XCTAssertTrue(archive.entries.isEmpty)
        XCTAssertTrue(archive.record(progress, on: date(2), value: 0, calendar: calendar))
        XCTAssertTrue(archive.record(checkIn, on: date(2), checkIn: .failed, calendar: calendar))
        let recorded = archive
        XCTAssertFalse(archive.record(progress, on: date(2), value: .nan, calendar: calendar))
        XCTAssertFalse(archive.record(checkIn, on: date(2), calendar: calendar))
        XCTAssertEqual(archive, recorded)
    }

    func testEntryIndexesFollowPublicMutationsAndValueCopies() throws {
        let first = habit()
        let second = habit()
        var archive = HabitArchive(habits: [first, second])
        XCTAssertTrue(archive.record(first, on: date(2), value: 100, calendar: calendar))
        XCTAssertTrue(archive.record(first, on: date(3), value: 100, calendar: calendar))
        XCTAssertTrue(archive.record(second, on: date(2), value: 20, calendar: calendar))
        let original = archive
        archive.entries.swapAt(0, 2)
        XCTAssertEqual(archive.entry(for: first, on: date(2), calendar: calendar)?.value, 100)
        archive.entries[2].value = 40
        XCTAssertEqual(archive.entry(for: first, on: date(2), calendar: calendar)?.value, 40)
        XCTAssertEqual(original.entry(for: first, on: date(2), calendar: calendar)?.value, 100)
        archive.entries[2].day = HabitDay(date(4), calendar: calendar)
        XCTAssertNil(archive.entry(for: first, on: date(2), calendar: calendar))
        XCTAssertEqual(archive.entry(for: first, on: date(4), calendar: calendar)?.value, 40)
        archive.entries[2].habitID = second.id
        XCTAssertNil(archive.entry(for: first, on: date(4), calendar: calendar))
        XCTAssertEqual(archive.entry(for: second, on: date(4), calendar: calendar)?.value, 40)
        archive.entries.removeFirst()
        XCTAssertNil(archive.entry(for: second, on: date(2), calendar: calendar))
        XCTAssertEqual(archive.streak(for: first, through: date(3), calendar: calendar, now: date(4)), 1)
        archive.entries = Array(original.entries.reversed())
        XCTAssertEqual(archive.samples(for: first, days: 3, through: date(3), calendar: calendar).map(\.fraction),
                       [0, 1, 1])
        archive.entries.reverse()
        XCTAssertEqual(archive, original)
        let decoded = try ArchiveFile.decode(ArchiveFile.encode(archive))
        XCTAssertEqual(decoded.entry(for: second, on: date(2), calendar: calendar)?.value, 20)
        archive.habits.removeAll { $0.id == second.id }
        XCTAssertFalse(archive.record(second, on: date(2), value: 50, calendar: calendar))
        archive.entries.removeAll()
        XCTAssertNil(archive.entry(for: first, on: date(2), calendar: calendar))
        XCTAssertTrue(archive.record(first, on: date(2), value: 10, calendar: calendar))
        archive.clear(first, on: date(2), calendar: calendar)
        XCTAssertNil(archive.entry(for: first, on: date(2), calendar: calendar))
        archive.entries.append(original.entries[0])
        archive.entries.append(original.entries[1])
        XCTAssertEqual(archive.entry(for: first, on: date(3), calendar: calendar)?.value, 100)
        archive.clear(first, on: date(2), calendar: calendar)
        XCTAssertEqual(archive.entry(for: first, on: date(3), calendar: calendar)?.value, 100)
        archive.entries.removeAll { $0.habitID == first.id }
        XCTAssertNil(archive.entry(for: first, on: date(3), calendar: calendar))
    }

    func testPassFailDefaultsAndExplicitOverrides() {
        let habit = habit(kind: .checkIn)
        var archive = HabitArchive(habits: [habit])
        XCTAssertNil(archive.entry(for: habit, on: date(4), calendar: calendar))
        XCTAssertTrue(archive.isComplete(habit, on: date(4), calendar: calendar))
        archive.record(habit, on: date(4), checkIn: .failed, calendar: calendar)
        XCTAssertEqual(archive.entry(for: habit, on: date(4), calendar: calendar)?.checkIn, .failed)
        XCTAssertFalse(archive.isComplete(habit, on: date(4), calendar: calendar))
        archive.record(habit, on: date(4), checkIn: .passed, calendar: calendar)
        XCTAssertTrue(archive.isComplete(habit, on: date(4), calendar: calendar))
        XCTAssertEqual(archive.entries.count, 1)
        archive.clear(habit, on: date(4), calendar: calendar)
        XCTAssertTrue(archive.entries.isEmpty)
        XCTAssertTrue(archive.isComplete(habit, on: date(4), calendar: calendar))
    }

    func testDefaultsRespectCreationFutureAndNumericHabits() {
        let checkIn = habit(kind: .checkIn)
        let numeric = habit()
        let archive = HabitArchive(habits: [checkIn, numeric])
        XCTAssertNil(archive.effectiveEntry(for: checkIn, on: date(1, month: 2), calendar: calendar, now: date(6)))
        XCTAssertNil(archive.effectiveEntry(for: checkIn, on: date(7), calendar: calendar, now: date(6)))
        XCTAssertNil(archive.effectiveEntry(for: numeric, on: date(5), calendar: calendar, now: date(6)))
        let samples = archive.samples(for: checkIn, days: 3, through: date(3), calendar: calendar)
        XCTAssertEqual(samples.map(\.fraction), [1, 1, 1])
        XCTAssertTrue(samples.allSatisfy(\.isDefault))
        XCTAssertTrue(archive.entries.isEmpty)
    }

    func testFailedDefaultCanBePassedAndCleared() throws {
        var habit = habit(kind: .checkIn)
        habit.defaultPassed = false
        var archive = HabitArchive(habits: [habit])
        XCTAssertEqual(archive.effectiveEntry(for: habit, on: date(1), calendar: calendar)?.checkIn, .failed)
        XCTAssertFalse(archive.isComplete(habit, on: date(1), calendar: calendar))
        XCTAssertTrue(archive.entries.isEmpty)
        archive.record(habit, on: date(2), checkIn: .passed, calendar: calendar)
        XCTAssertTrue(archive.isComplete(habit, on: date(2), calendar: calendar))
        XCTAssertEqual(archive.streak(for: habit, through: date(2), calendar: calendar), 1)
        let samples = archive.samples(for: habit, days: 3, through: date(3), calendar: calendar)
        XCTAssertEqual(samples.map(\.fraction), [0, 1, 0])
        XCTAssertEqual(samples.map(\.isDefault), [true, false, true])
        archive.clear(habit, on: date(2), calendar: calendar)
        XCTAssertEqual(archive.effectiveEntry(for: habit, on: date(2), calendar: calendar)?.checkIn, .failed)
        XCTAssertTrue(archive.entries.isEmpty)
        XCTAssertEqual(try ArchiveFile.decode(ArchiveFile.encode(archive)), archive)
    }

    func testChangingDefaultOnlyUpdatesUnrecordedDaysAndIsPerHabit() throws {
        var first = habit(kind: .checkIn)
        let second = habit(kind: .checkIn)
        var archive = HabitArchive(habits: [first, second])
        archive.record(first, on: date(2), checkIn: .passed, calendar: calendar)
        archive.record(first, on: date(3), checkIn: .failed, calendar: calendar)
        let recorded = archive.entries
        for passed in [false, true] {
            first.defaultPassed = passed
            archive.habits[0] = first
            XCTAssertEqual(archive.isComplete(first, on: date(1), calendar: calendar), passed)
            XCTAssertTrue(archive.isComplete(second, on: date(1), calendar: calendar))
            XCTAssertTrue(archive.isComplete(first, on: date(2), calendar: calendar))
            XCTAssertFalse(archive.isComplete(first, on: date(3), calendar: calendar))
            XCTAssertEqual(archive.entries, recorded)
            XCTAssertEqual(try ArchiveFile.decode(ArchiveFile.encode(archive)), archive)
        }
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

    func testSwitchingToPassFailPreservesAndCanEditRecordedProgress() throws {
        var habit = habit()
        var archive = HabitArchive(habits: [habit])
        archive.record(habit, on: date(5), value: 100, calendar: calendar)
        let original = try XCTUnwrap(archive.entry(for: habit, on: date(5), calendar: calendar))
        habit = Habit(id: habit.id, name: habit.name, emoji: habit.emoji, color: habit.color,
                      kind: .checkIn, createdAt: habit.createdAt, startDay: habit.startDay)
        archive.habits[0] = habit

        XCTAssertEqual(archive.entry(for: habit, on: date(5), calendar: calendar), original)
        XCTAssertTrue(archive.isComplete(habit, on: date(5), calendar: calendar))
        archive.record(habit, on: date(5), value: 50, calendar: calendar)
        let edited = try XCTUnwrap(archive.entry(for: habit, on: date(5), calendar: calendar))
        XCTAssertEqual(edited.id, original.id)
        XCTAssertEqual(edited.kind, .progress)
        XCTAssertEqual(edited.target, 100)
        XCTAssertEqual(edited.unit, "steps")
        XCTAssertEqual(edited.value, 50)
        XCTAssertFalse(edited.isComplete)

        XCTAssertEqual(archive.effectiveEntry(for: habit, on: date(6), calendar: calendar)?.checkIn, .passed)
        archive.record(habit, on: date(6), checkIn: .failed, calendar: calendar)
        XCTAssertFalse(archive.isComplete(habit, on: date(6), calendar: calendar))
        XCTAssertEqual(try ArchiveFile.decode(ArchiveFile.encode(archive)), archive)

        archive.clear(habit, on: date(5), calendar: calendar)
        archive.record(habit, on: date(5), checkIn: .passed, calendar: calendar)
        XCTAssertEqual(archive.entry(for: habit, on: date(5), calendar: calendar)?.kind, .checkIn)
    }

    func testSwitchingToProgressPreservesAndCanEditRecordedPassFail() throws {
        var habit = habit(kind: .checkIn)
        var archive = HabitArchive(habits: [habit])
        archive.record(habit, on: date(5), checkIn: .failed, calendar: calendar)
        let original = try XCTUnwrap(archive.entry(for: habit, on: date(5), calendar: calendar))
        habit = Habit(id: habit.id, name: habit.name, emoji: habit.emoji, color: habit.color,
                      kind: .progress, target: 20, step: 5, unit: "pages", createdAt: habit.createdAt,
                      startDay: habit.startDay)
        archive.habits[0] = habit

        XCTAssertEqual(archive.entry(for: habit, on: date(5), calendar: calendar), original)
        archive.record(habit, on: date(5), checkIn: .passed, calendar: calendar)
        XCTAssertEqual(archive.entry(for: habit, on: date(5), calendar: calendar)?.kind, .checkIn)
        XCTAssertTrue(archive.isComplete(habit, on: date(5), calendar: calendar))
        XCTAssertNil(archive.effectiveEntry(for: habit, on: date(6), calendar: calendar))
        archive.record(habit, on: date(6), value: 10, calendar: calendar)
        XCTAssertEqual(archive.entry(for: habit, on: date(6), calendar: calendar)?.kind, .progress)
        XCTAssertFalse(archive.isComplete(habit, on: date(6), calendar: calendar))
        XCTAssertEqual(try ArchiveFile.decode(ArchiveFile.encode(archive)), archive)
    }

    func testRejectsInvalidValuesAndOutOfRangeDates() {
        let habit = habit()
        var archive = HabitArchive(habits: [habit])
        for invalid in [Decimal(-1), .nan] {
            XCTAssertFalse(archive.record(habit, on: date(5), value: invalid, calendar: calendar))
        }
        XCTAssertFalse(archive.record(habit, on: date(1, month: 2), value: 30, calendar: calendar))
        XCTAssertFalse(archive.record(habit, on: date(7), value: 30, calendar: calendar, now: date(6)))
        XCTAssertTrue(archive.entries.isEmpty)
        XCTAssertTrue(archive.record(habit, on: date(5), value: 0, calendar: calendar))
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

    func testStreakIncludesDefaultPassesAndStopsAtFailure() {
        let habit = habit(kind: .checkIn)
        var archive = HabitArchive(habits: [habit])
        archive.record(habit, on: date(5), checkIn: .failed, calendar: calendar)
        archive.record(habit, on: date(6), checkIn: .passed, calendar: calendar)
        archive.record(habit, on: date(7), checkIn: .passed, calendar: calendar)
        XCTAssertEqual(archive.streak(for: habit, through: date(7), calendar: calendar), 2)
        XCTAssertEqual(archive.streak(for: habit, through: date(8), calendar: calendar), 3)
    }

    func testUnfinishedTodayPreservesYesterdayStreak() {
        let now = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
        let habit = Habit(name: "Read", emoji: "📚", color: .rose, kind: .checkIn, createdAt: yesterday,
                          calendar: calendar)
        var archive = HabitArchive(habits: [habit])
        archive.record(habit, on: yesterday, checkIn: .passed, calendar: calendar)
        XCTAssertEqual(archive.streak(for: habit, through: now, calendar: calendar), 2)
        archive.record(habit, on: now, checkIn: .passed, calendar: calendar)
        XCTAssertEqual(archive.streak(for: habit, through: now, calendar: calendar), 2)
        archive.record(habit, on: now, checkIn: .failed, calendar: calendar)
        XCTAssertEqual(archive.streak(for: habit, through: now, calendar: calendar), 0)
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
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(archive).write(to: file.url)
        XCTAssertThrowsError(try file.load())
        try Data("broken".utf8).write(to: file.url)
        XCTAssertThrowsError(try file.load())
        XCTAssertEqual(try String(contentsOf: file.url, encoding: .utf8), "broken")
    }
}
