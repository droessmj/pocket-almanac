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
              unit: "pages", createdAt: createdAt ?? date(), defaultPassed: defaultPassed)
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

    func testLegacyConversionRequiresChoiceAndPreservesSnapshotsAndIDs() throws {
        let originalHabit = habit(kind: .progress)
        var original = HabitArchive(habits: [originalHabit])
        original.record(originalHabit, on: date(2026, 3, 8), value: 25, calendar: calendar, now: date(2026, 3, 9))
        original.habits[0].target = 40
        original.habits[0].kind = .checkIn
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: ArchiveFile.encode(original)) as? [String: Any])
        object["version"] = 1
        var entries = try XCTUnwrap(object["entries"] as? [[String: Any]])
        entries[0]["day"] = ["year": 2569, "month": 3, "day": 8]
        object["entries"] = entries
        var habits = try XCTUnwrap(object["habits"] as? [[String: Any]])
        habits[0].removeValue(forKey: "defaultPassed")
        object["habits"] = habits
        let legacy = try JSONSerialization.data(withJSONObject: object)
        XCTAssertThrowsError(try ArchiveFile.decode(legacy)) { error in
            guard case ArchiveValidationError.legacyCalendarRequired = error else { return XCTFail("\(error)") }
        }
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = calendar.timeZone
        let migrated = try ArchiveFile.decode(legacy, legacyCalendar: buddhist)
        XCTAssertEqual(migrated, original)
        XCTAssertEqual(migrated.version, 2)
        XCTAssertEqual(migrated.entries[0].target, 20)
        XCTAssertEqual(migrated.entries[0].kind, .progress)
        XCTAssertTrue(migrated.habits[0].defaultPassed)
        XCTAssertEqual(try ArchiveFile.decode(ArchiveFile.encode(migrated)), migrated)

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = ArchiveFile(url: directory.appendingPathComponent("archive.json"))
        try legacy.write(to: file.url)
        XCTAssertThrowsError(try file.load())
        XCTAssertEqual(try file.load(legacyCalendar: buddhist), original)
        XCTAssertEqual(try Data(contentsOf: file.url), legacy, "Reading a migration must not rewrite user bytes")
        try file.save(migrated)
        XCTAssertEqual(try file.load(), original)
    }

    func testLegacyRejectsNormalizedImpossibleDayWithoutChangingSource() throws {
        var object: [String: Any]
        let habit = habit()
        var archive = HabitArchive(habits: [habit])
        archive.record(habit, on: date(), checkIn: .passed, calendar: calendar, now: date())
        object = try XCTUnwrap(JSONSerialization.jsonObject(with: ArchiveFile.encode(archive)) as? [String: Any])
        object["version"] = 1
        var entries = try XCTUnwrap(object["entries"] as? [[String: Any]])
        entries[0]["day"] = ["year": 2026, "month": 2, "day": 30]
        object["entries"] = entries
        XCTAssertThrowsError(try ArchiveFile.decode(JSONSerialization.data(withJSONObject: object), legacyCalendar: calendar))
    }

    func testAmbiguousLegacyCalendarsRejectWithoutTouchingOriginalBytes() throws {
        let habit = habit()
        var archive = HabitArchive(habits: [habit])
        archive.record(habit, on: date(), checkIn: .passed, calendar: calendar, now: date())
        archive.version = 1
        let bytes = try JSONEncoder().encode(archive)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = ArchiveFile(url: directory.appendingPathComponent("archive.json"))
        try bytes.write(to: file.url)
        for identifier in [Calendar.Identifier.japanese, .chinese, .republicOfChina, .ethiopicAmeteMihret] {
            var source = Calendar(identifier: identifier)
            source.timeZone = calendar.timeZone
            XCTAssertThrowsError(try file.load(legacyCalendar: source)) { error in
                guard case ArchiveValidationError.ambiguousLegacyCalendar = error else { return XCTFail("\(error)") }
            }
            XCTAssertEqual(try Data(contentsOf: file.url), bytes)
        }
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
            let archive = HabitArchive(habits: [habit(createdAt: valid)])
            XCTAssertEqual(try ArchiveFile.decode(ArchiveFile.encode(archive)), archive)
        }
        for invalid in [lower.addingTimeInterval(-1), upper, Date(timeIntervalSinceReferenceDate: .infinity)] {
            XCTAssertThrowsError(try ArchiveFile.encode(HabitArchive(habits: [habit(createdAt: invalid)])))
        }
        let habit = habit(createdAt: lower)
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
