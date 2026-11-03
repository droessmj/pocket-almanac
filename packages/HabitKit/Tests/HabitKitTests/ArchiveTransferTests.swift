import Foundation
import XCTest
@testable import HabitKit

final class ArchiveTransferTests: XCTestCase {
    private func backup() -> HabitArchive {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let created = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 12))!
        let logged = calendar.date(from: DateComponents(year: 2026, month: 3, day: 4, hour: 12))!
        var progress = Habit(name: "Read 📚", emoji: "📖", color: .mint, kind: .progress,
                             target: 20, step: 5, unit: "pages", createdAt: created, isArchived: true)
        let checkIn = Habit(name: "No snacks", emoji: "🍎", color: .rose, kind: .checkIn,
                            createdAt: created, defaultPassed: false)
        var result = HabitArchive(habits: [progress, checkIn])
        result.record(progress, on: logged, value: 25, calendar: calendar)
        result.record(checkIn, on: logged, checkIn: .failed, calendar: calendar)
        progress.target = 40
        progress.unit = "chapters"
        result.habits[0] = progress
        return result
    }

    func testBackupRoundTripPreservesAllDataAndHistoricalGoals() throws {
        let original = backup()
        let data = try ArchiveFile.encode(original)
        let imported = try ArchiveFile.decode(data)
        XCTAssertEqual(imported, original)
        XCTAssertTrue(imported.habits[0].isArchived)
        XCTAssertEqual(imported.entries[0].target, 20)
        XCTAssertEqual(imported.entries[0].unit, "pages")
        XCTAssertEqual(imported.entries[1].checkIn, .failed)
        XCTAssertFalse(imported.habits[1].defaultPassed)
        XCTAssertEqual(imported.habits[0].target, 40)
        XCTAssertEqual(try ArchiveFile.decode(ArchiveFile.encode(HabitArchive())), HabitArchive())
    }

    func testImportRejectsMalformedAndUnsupportedFiles() throws {
        for text in ["not JSON", "[]", "{}", "{\"version\":99,\"habits\":[],\"entries\":[]}"] {
            XCTAssertThrowsError(try ArchiveFile.decode(Data(text.utf8)), text)
        }
    }

    func testImportRejectsDuplicateOrDanglingRecords() throws {
        let valid = backup()
        var invalid: [HabitArchive] = []
        var duplicateHabit = valid
        duplicateHabit.habits.append(valid.habits[0])
        invalid.append(duplicateHabit)
        var duplicateDay = valid
        var repeated = duplicateDay.entries[0]
        repeated.id = UUID()
        duplicateDay.entries.append(repeated)
        invalid.append(duplicateDay)
        var duplicateID = valid
        duplicateID.entries[1].id = duplicateID.entries[0].id
        invalid.append(duplicateID)
        var dangling = valid
        dangling.entries[0].habitID = UUID()
        invalid.append(dangling)
        var unexpectedCheckIn = valid
        unexpectedCheckIn.entries[0].checkIn = .passed
        invalid.append(unexpectedCheckIn)
        var missingCheckIn = valid
        missingCheckIn.entries[1].checkIn = nil
        invalid.append(missingCheckIn)
        for archive in invalid {
            let raw = try JSONEncoder().encode(archive)
            XCTAssertThrowsError(try ArchiveFile.decode(raw))
        }
    }

    func testImportRejectsImpossibleDatesAndInvalidValues() throws {
        let valid = backup()
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(valid)) as? [String: Any])
        var entries = try XCTUnwrap(object["entries"] as? [[String: Any]])
        entries[0]["day"] = ["year": 2026, "month": 2, "day": 30]
        var invalidDate = object
        invalidDate["entries"] = entries
        XCTAssertThrowsError(try ArchiveFile.decode(JSONSerialization.data(withJSONObject: invalidDate)))
        for value in [-1, Double.nan, Double.infinity] {
            var invalid = valid
            invalid.entries[0].value = value
            XCTAssertThrowsError(try ArchiveFile.encode(invalid))
        }
    }

    func testInvalidRestorePreservesExistingFileBytes() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("DayInInkTransfer-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = ArchiveFile(url: directory.appendingPathComponent("habits.json"))
        let original = backup()
        try file.save(original)
        let saved = try Data(contentsOf: file.url)
        var invalid = original
        invalid.habits[0].name = " "
        XCTAssertThrowsError(try file.save(invalid))
        XCTAssertEqual(try Data(contentsOf: file.url), saved)
        XCTAssertEqual(try file.load(), original)
        let replacement = HabitArchive()
        try file.save(ArchiveFile.decode(ArchiveFile.encode(replacement)))
        XCTAssertEqual(try file.load(), replacement)
    }
}
