import Foundation
import XCTest
@testable import HabitKit

final class ArchiveBoundsAndCalendarTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "America/Chicago")!
        return value
    }

    private func date(_ year: Int = 2026, _ month: Int = 3, _ day: Int = 1, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func habit(createdAt: Date? = nil, kind: HabitKind = .checkIn, defaultPassed: Bool = true) -> Habit {
        Habit(name: "Read", emoji: "📚", color: .mint, kind: kind, target: 20, step: 5,
              unit: "pages", createdAt: createdAt ?? date(), defaultPassed: defaultPassed, calendar: calendar)
    }

    func testTimezoneTravelKeepsStartDayAndRecordedKeysInBothDirections() throws {
        for (originZone, destinationZone, hour) in [
            ("Asia/Tokyo", "America/Los_Angeles", 0),
            ("America/Los_Angeles", "Asia/Tokyo", 23)
        ] {
            var origin = Calendar(identifier: .gregorian)
            origin.timeZone = try XCTUnwrap(TimeZone(identifier: originZone))
            var destination = Calendar(identifier: .buddhist)
            destination.timeZone = try XCTUnwrap(TimeZone(identifier: destinationZone))
            let created = try XCTUnwrap(origin.date(from: DateComponents(year: 2026, month: 3, day: 2,
                                                                        hour: hour, minute: 30)))
            let habit = Habit(name: "Travel", emoji: "🌏", color: .blue, kind: .checkIn,
                              createdAt: created, calendar: origin)
            let key = HabitDay(created, calendar: origin)
            XCTAssertNotEqual(key, HabitDay(created, calendar: destination))
            let localStart = try XCTUnwrap(habit.startDate(calendar: destination))
            let localCalendar = HabitDay.localCalendar(destination)
            let now = try XCTUnwrap(localCalendar.date(byAdding: .day, value: 2, to: localStart))
            let before = try XCTUnwrap(localCalendar.date(byAdding: .day, value: -1, to: localStart))
            var archive = HabitArchive(habits: [habit])
            XCTAssertEqual(habit.createdAt, created)
            XCTAssertEqual(HabitDay(localStart, calendar: destination), key)
            XCTAssertNil(archive.effectiveEntry(for: habit, on: before, calendar: destination, now: now))
            XCTAssertFalse(archive.record(habit, on: before, checkIn: .passed, calendar: destination, now: now))
            XCTAssertEqual(archive.streak(for: habit, through: before, calendar: destination, now: now), 0)
            XCTAssertTrue(archive.samples(for: habit, days: 4, through: before, calendar: destination).isEmpty)
            XCTAssertNil(habit.historyDateRange(through: before, calendar: destination))
            XCTAssertEqual(habit.historyDateRange(through: now, calendar: destination)?.lowerBound, localStart)
            XCTAssertEqual(archive.streak(for: habit, through: now, calendar: destination, now: now), 3)
            XCTAssertEqual(archive.samples(for: habit, days: 4, through: now, calendar: destination).count, 3)
            XCTAssertTrue(archive.record(habit, on: created, checkIn: .failed, calendar: origin, now: now))
            let recorded = try XCTUnwrap(archive.entry(for: habit, on: localStart, calendar: destination))
            XCTAssertEqual(recorded.day, key)
            XCTAssertEqual(recorded.checkIn, .failed)
            XCTAssertTrue(archive.record(habit, on: localStart, checkIn: .passed, calendar: destination, now: now))
            XCTAssertEqual(archive.entries.count, 1)
            XCTAssertEqual(archive.entry(for: habit, on: created, calendar: origin)?.id, recorded.id)
            XCTAssertEqual(archive.effectiveEntry(for: habit, on: localStart, calendar: destination, now: now)?.checkIn,
                           .passed)
            let decoded = try ArchiveFile.decode(ArchiveFile.encode(archive))
            XCTAssertEqual(decoded, archive)
            XCTAssertEqual(decoded.habits[0].startDay, key)
            XCTAssertEqual(decoded.entries[0].day, key)
        }
    }

    func testHistoryRemainsEditableWhenTimezoneSkipsTheStartDay() throws {
        var origin = Calendar(identifier: .gregorian)
        origin.timeZone = TimeZone(secondsFromGMT: 0)!
        let created = try XCTUnwrap(origin.date(from: DateComponents(year: 2011, month: 12, day: 30, hour: 12)))
        let habit = Habit(name: "Travel", emoji: "🌏", color: .blue, kind: .checkIn,
                          createdAt: created, calendar: origin)
        var destination = Calendar(identifier: .gregorian)
        destination.timeZone = try XCTUnwrap(TimeZone(identifier: "Pacific/Apia"))
        let now = try XCTUnwrap(destination.date(from: DateComponents(year: 2012, month: 1, day: 2, hour: 12)))
        let expectedStart = try XCTUnwrap(destination.date(from: DateComponents(year: 2011, month: 12, day: 31)))
        XCTAssertNil(habit.startDate(calendar: destination))
        let range = try XCTUnwrap(habit.historyDateRange(through: now, calendar: destination))
        XCTAssertEqual(range.lowerBound, expectedStart)
        XCTAssertEqual(range.upperBound, now)
        var archive = HabitArchive(habits: [habit])
        XCTAssertTrue(archive.record(habit, on: range.lowerBound, checkIn: .passed,
                                     calendar: destination, now: now))
        XCTAssertEqual(archive.entry(for: habit, on: expectedStart, calendar: destination)?.checkIn, .passed)
        XCTAssertEqual(habit.startDay, HabitDay(created, calendar: origin))
    }

    private func assertResourceLimit(_ operation: () throws -> Void, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertThrowsError(try operation(), file: file, line: line) { error in
            guard case ArchiveValidationError.resourceLimitExceeded = error else {
                return XCTFail("Expected resource limit, got \(error)", file: file, line: line)
            }
        }
    }

    func testCalendarPreferenceSwitchFindsAndUpdatesSameActualLocalDay() throws {
        let habit = habit(kind: .progress)
        var archive = HabitArchive(habits: [habit])
        archive.record(habit, on: date(2026, 3, 8, hour: 1), value: 10, calendar: calendar, now: date(2026, 3, 9))
        let originalID = try XCTUnwrap(archive.entries.first?.id)
        for identifier in [Calendar.Identifier.buddhist, .hebrew, .islamicCivil, .japanese] {
            var switched = Calendar(identifier: identifier)
            switched.timeZone = calendar.timeZone
            XCTAssertEqual(archive.entry(for: habit, on: date(2026, 3, 8, hour: 23), calendar: switched)?.id, originalID)
            archive.record(habit, on: date(2026, 3, 8, hour: 23), value: 15, calendar: switched, now: date(2026, 3, 9))
            XCTAssertEqual(archive.entries.count, 1)
            XCTAssertEqual(archive.entries[0].id, originalID)
            XCTAssertEqual(archive.entries[0].value, 15)
            XCTAssertEqual(archive.samples(for: habit, days: 3, through: date(2026, 3, 9), calendar: switched).map(\.fraction), [0, 0.75, 0])
        }
        XCTAssertEqual(try ArchiveFile.decode(ArchiveFile.encode(archive)), archive)
    }

    func testDayIdentityStillUsesLocalTimezoneAndFallDST() {
        let instant = date(2026, 11, 1, hour: 23)
        var utc = Calendar(identifier: .buddhist)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        XCTAssertNotEqual(HabitDay(instant, calendar: calendar), HabitDay(instant, calendar: utc))
        XCTAssertEqual(HabitDay(date(2026, 11, 1, hour: 1), calendar: calendar),
                       HabitDay(date(2026, 11, 1, hour: 23), calendar: calendar))
    }


    func testDataAndURLByteLimitsIncludeExactBoundaryAndRejectExcess() throws {
        let encoded = try ArchiveFile.encode(HabitArchive())
        var boundary = encoded
        boundary.append(Data(repeating: 0x20, count: ArchiveLimits.maxBytes - encoded.count))
        XCTAssertEqual(try ArchiveFile.decode(boundary), HabitArchive())
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("large.json")
        try boundary.write(to: url)
        XCTAssertEqual(try ArchiveFile.read(from: url), HabitArchive())
        boundary.append(0x20)
        assertResourceLimit { _ = try ArchiveFile.decode(boundary) }
        try boundary.write(to: url)
        assertResourceLimit { _ = try ArchiveFile.read(from: url) }
        assertResourceLimit { _ = try ArchiveFile(url: url).load() }
    }

    func testHabitCountBoundaryAndEntryCountExcess() throws {
        let habits = (0..<ArchiveLimits.maxHabits).map { _ in habit() }
        let boundary = HabitArchive(habits: habits)
        XCTAssertEqual(try ArchiveFile.decode(ArchiveFile.encode(boundary)), boundary)
        var excess = boundary
        excess.habits.append(habit())
        assertResourceLimit { _ = try ArchiveFile.encode(excess) }
        assertResourceLimit { _ = try ArchiveFile.decode(JSONEncoder().encode(excess)) }
        // The total byte cap can bind before the independent 100,000-entry ceiling.
        let entry = HabitEntry(habit: habits[0], date: date(), checkIn: .passed, calendar: calendar)
        let excessEntries = HabitArchive(habits: [habits[0]], entries: Array(repeating: entry, count: ArchiveLimits.maxEntries + 1))
        assertResourceLimit { _ = try ArchiveFile.encode(excessEntries) }
    }

    func testUnicodeTextBoundariesIncludeHistoricalUnits() throws {
        var habit = habit(kind: .progress)
        habit.name = String(repeating: "界", count: ArchiveLimits.maxNameScalars)
        habit.emoji = String(repeating: "📚", count: ArchiveLimits.maxEmojiScalars)
        habit.unit = String(repeating: "頁", count: ArchiveLimits.maxUnitScalars)
        var archive = HabitArchive(habits: [habit])
        archive.record(habit, on: date(), value: 20, calendar: calendar, now: date())
        XCTAssertEqual(try ArchiveFile.decode(ArchiveFile.encode(archive)), archive)
        for field in 0..<4 {
            var invalid = archive
            switch field {
            case 0: invalid.habits[0].name += "\u{301}"
            case 1: invalid.habits[0].emoji += "📚"
            case 2: invalid.habits[0].unit += "頁"
            default: invalid.entries[0].unit += "頁"
            }
            XCTAssertThrowsError(try ArchiveFile.encode(invalid))
            XCTAssertThrowsError(try ArchiveFile.decode(JSONEncoder().encode(invalid)))
        }
    }

    func testGregorianDateBoundsAndClockRollbackCreationDate() throws {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let lower = utc.date(from: DateComponents(year: 1900, month: 1, day: 1))!
        let upper = utc.date(from: DateComponents(year: 10000, month: 1, day: 1))!
        for valid in [lower, upper.addingTimeInterval(-1), date(2099)] {
            let habit = Habit(name: "Bounds", emoji: "📚", color: .mint, kind: .checkIn,
                              createdAt: valid, calendar: utc)
            let archive = HabitArchive(habits: [habit])
            XCTAssertEqual(try ArchiveFile.decode(ArchiveFile.encode(archive)), archive)
        }
        for invalid in [lower.addingTimeInterval(-1), upper, Date(timeIntervalSinceReferenceDate: .infinity)] {
            XCTAssertThrowsError(try ArchiveFile.encode(HabitArchive(habits: [habit(createdAt: invalid)])))
        }
        let habit = Habit(name: "Bounds", emoji: "📚", color: .mint, kind: .checkIn,
                          createdAt: lower, calendar: utc)
        for valid in [lower, upper.addingTimeInterval(-1)] {
            let entry = HabitEntry(habit: habit, date: valid, checkIn: .passed, calendar: utc)
            let archive = HabitArchive(habits: [habit], entries: [entry])
            XCTAssertEqual(try ArchiveFile.decode(ArchiveFile.encode(archive)), archive)
        }
        for invalid in [lower.addingTimeInterval(-1), upper] {
            let entry = HabitEntry(habit: habit, date: invalid, checkIn: .passed, calendar: utc)
            XCTAssertThrowsError(try ArchiveFile.encode(HabitArchive(habits: [habit], entries: [entry])))
        }
    }

    func testRejectedResourceAndTextRestorePreservesExistingBytes() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = ArchiveFile(url: directory.appendingPathComponent("archive.json"))
        let original = HabitArchive(habits: [habit()])
        try file.save(original)
        let bytes = try Data(contentsOf: file.url)
        var invalid = original
        invalid.habits[0].name = String(repeating: "a", count: ArchiveLimits.maxNameScalars + 1)
        XCTAssertThrowsError(try file.save(invalid))
        invalid = HabitArchive(habits: (0...ArchiveLimits.maxHabits).map { _ in habit() })
        assertResourceLimit { try file.save(invalid) }
        XCTAssertEqual(try Data(contentsOf: file.url), bytes)
        XCTAssertEqual(try file.load(), original)
    }

    func testLongImplicitStreakUsesGapsAndHistoricalExplicitFailures() {
        let created = date(1900, 1, 1)
        let end = date(9999, 12, 30)
        let habit = habit(createdAt: created)
        var archive = HabitArchive(habits: [habit])
        let total = calendar.dateComponents([.day], from: calendar.startOfDay(for: created),
                                            to: calendar.startOfDay(for: end)).day! + 1
        XCTAssertEqual(archive.streak(for: habit, through: end, calendar: calendar, now: end), total)
        archive.record(habit, on: date(9999, 12, 25), checkIn: .failed, calendar: calendar, now: end)
        archive.record(habit, on: date(1950, 1, 1), checkIn: .failed, calendar: calendar, now: end)
        archive.record(habit, on: date(9999, 12, 29), checkIn: .passed, calendar: calendar, now: end)
        XCTAssertEqual(archive.streak(for: habit, through: end, calendar: calendar, now: end), 5)
        archive.clear(habit, on: date(9999, 12, 25), calendar: calendar)
        let afterOldFailure = calendar.dateComponents([.day], from: calendar.startOfDay(for: date(1950, 1, 1)),
                                                      to: calendar.startOfDay(for: end)).day!
        XCTAssertEqual(archive.streak(for: habit, through: end, calendar: calendar, now: end), afterOldFailure)
        archive.record(habit, on: end, checkIn: .failed, calendar: calendar, now: end)
        XCTAssertEqual(archive.streak(for: habit, through: end, calendar: calendar, now: end), 0)
    }

    func testLongNonImplicitStreakStopsAtGapAndUnfinishedTodaySkipsOnce() {
        let end = date(9999, 12, 30)
        let habit = habit(createdAt: date(1900, 1, 1), kind: .progress)
        var archive = HabitArchive(habits: [habit])
        for day in [25, 28, 29] {
            archive.record(habit, on: date(9999, 12, day), value: 20, calendar: calendar, now: end)
        }
        XCTAssertEqual(archive.streak(for: habit, through: end, calendar: calendar, now: end), 2)
        XCTAssertEqual(archive.streak(for: habit, through: end, calendar: calendar, now: date(9999, 12, 31)), 0)
        archive.record(habit, on: end, value: 20, calendar: calendar, now: end)
        XCTAssertEqual(archive.streak(for: habit, through: end, calendar: calendar, now: end), 3)
        var checkIn = habit
        checkIn.kind = .checkIn
        checkIn.defaultPassed = false
        archive.habits[0] = checkIn
        // Current defaults must not replace recorded progress snapshots.
        XCTAssertEqual(archive.streak(for: checkIn, through: end, calendar: calendar, now: end), 3)
    }

    func testHistoryRangeHandlesClockRollbackSameDayAndChangedCalendar() throws {
        let now = date(2026, 3, 8, hour: 10)
        let future = habit(createdAt: date(2026, 3, 9))
        XCTAssertNil(future.historyDateRange(through: now, calendar: calendar))
        let sameDayFuture = habit(createdAt: date(2026, 3, 8, hour: 23))
        let sameDay = try XCTUnwrap(sameDayFuture.historyDateRange(through: now, calendar: calendar))
        XCTAssertEqual(sameDay.lowerBound, calendar.startOfDay(for: now))
        XCTAssertEqual(sameDay.upperBound, now)
        let older = habit(createdAt: date())
        let normal = try XCTUnwrap(older.historyDateRange(through: now, calendar: calendar))
        XCTAssertEqual(normal.lowerBound, calendar.startOfDay(for: date()))
        XCTAssertEqual(normal.upperBound, now)
        var switched = Calendar(identifier: .buddhist)
        switched.timeZone = calendar.timeZone
        XCTAssertEqual(older.historyDateRange(through: now, calendar: switched), normal)
        XCTAssertNil(future.historyDateRange(through: now, calendar: switched))
    }

    func testEncodedByteOverflowRejectsSaveBeforeReplacingExistingFile() throws {
        let habit = habit(createdAt: date(1900, 1, 1), kind: .progress)
        let entry = HabitEntry(habit: habit, date: date(1900, 1, 1), value: 20, calendar: calendar)
        // All 100,000 records have valid, unique IDs and days. The byte cap is independently binding.
        let entries = (0..<ArchiveLimits.maxEntries).map { offset in
            var result = entry
            result.id = UUID()
            result.day = HabitDay(calendar.date(byAdding: .day, value: offset, to: habit.createdAt)!, calendar: calendar)
            return result
        }
        let oversized = HabitArchive(habits: [habit], entries: entries)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = ArchiveFile(url: directory.appendingPathComponent("archive.json"))
        let original = HabitArchive(habits: [habit])
        try file.save(original)
        let bytes = try Data(contentsOf: file.url)
        assertResourceLimit { try file.save(oversized) }
        XCTAssertEqual(try Data(contentsOf: file.url), bytes)
        XCTAssertEqual(try file.load(), original)
    }
}
