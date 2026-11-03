import Foundation

/// Shared import and save limits. Text limits count Unicode scalars (not bytes or grapheme clusters).
/// Creation timestamps use UTC Gregorian years; day keys use local Gregorian years. Future dates are valid.
public enum ArchiveLimits {
    public static let maxBytes = 16 * 1024 * 1024
    public static let maxHabits = 1_000
    public static let maxEntries = 100_000
    public static let maxNameScalars = 256
    public static let maxEmojiScalars = 32
    public static let maxUnitScalars = 64
    public static let supportedYears = 1900...9999

    private static let earliestTimestamp: TimeInterval = -3_187_296_000 // 1900-01-01 UTC, relative to 2001.
    private static let latestTimestamp: TimeInterval = 252_423_993_600 // 10000-01-01 UTC, exclusive.

    static func contains(_ date: Date) -> Bool {
        let timestamp = date.timeIntervalSinceReferenceDate
        return timestamp.isFinite && timestamp >= earliestTimestamp && timestamp < latestTimestamp
    }

    static func validText(_ text: String, maximum: Int, required: Bool = false) -> Bool {
        guard text.unicodeScalars.count <= maximum else { return false }
        return !required || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

public struct ArchiveFile: Sendable {
    public let url: URL

    public init(url: URL) { self.url = url }

    public func load(legacyCalendar: Calendar? = nil) throws -> HabitArchive? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Self.read(from: url, legacyCalendar: legacyCalendar)
    }

    /// Reads at most the byte limit plus one sentinel byte, including files that grow during reading.
    /// No unbounded Data(contentsOf:) allocation occurs before validation.
    public static func read(from url: URL, legacyCalendar: Calendar? = nil) throws -> HabitArchive {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var data = Data()
        while true {
            let remaining = ArchiveLimits.maxBytes - data.count
            let chunk = try handle.read(upToCount: min(64 * 1024, remaining + 1)) ?? Data()
            guard !chunk.isEmpty else { break }
            guard chunk.count <= remaining else { throw ArchiveValidationError.resourceLimitExceeded }
            data.append(chunk)
        }
        return try decode(data, legacyCalendar: legacyCalendar)
    }

    /// v2 stores Gregorian local day keys. v1 did not record its calendar, era or leap-month identity.
    /// Callers must ask for the original calendar/timezone; no current-calendar inference is performed.
    /// Calendars with ambiguous era/cycle/leap-month keys are rejected rather than guessed.
    /// Migration never changes the source file; callers save only after accepting conversion.
    public static func decode(_ data: Data, legacyCalendar: Calendar? = nil) throws -> HabitArchive {
        guard data.count <= ArchiveLimits.maxBytes else { throw ArchiveValidationError.resourceLimitExceeded }
        var archive = try JSONDecoder().decode(HabitArchive.self, from: data)
        if archive.version == 1 {
            guard let legacyCalendar else { throw ArchiveValidationError.legacyCalendarRequired }
            if !archive.entries.isEmpty {
                switch legacyCalendar.identifier {
                case .gregorian, .iso8601, .buddhist, .hebrew, .islamic, .islamicCivil,
                     .islamicTabular, .islamicUmmAlQura, .persian, .indian, .coptic, .ethiopicAmeteAlem:
                    break
                default:
                    throw ArchiveValidationError.ambiguousLegacyCalendar
                }
            }
            for index in archive.entries.indices {
                let day = archive.entries[index].day
                guard (1...20_000).contains(day.year), (1...13).contains(day.month), (1...31).contains(day.day),
                      let date = legacyCalendar.date(from: DateComponents(year: day.year, month: day.month,
                                                                          day: day.day, hour: 12)) else {
                    throw ArchiveValidationError.invalidData
                }
                let parts = legacyCalendar.dateComponents([.year, .month, .day], from: date)
                guard parts.year == day.year, parts.month == day.month, parts.day == day.day else {
                    throw ArchiveValidationError.invalidData
                }
                archive.entries[index].day = HabitDay(date, calendar: legacyCalendar)
            }
            archive.version = 2
        }
        // A migrated import must also fit the canonical on-device representation before restoration.
        _ = try encode(archive)
        return archive
    }

    public static func encode(_ archive: HabitArchive) throws -> Data {
        try validate(archive)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(archive)
        guard data.count <= ArchiveLimits.maxBytes else { throw ArchiveValidationError.resourceLimitExceeded }
        return data
    }

    private struct EntryKey: Hashable {
        let habitID: UUID
        let day: HabitDay
    }

    private static func validate(_ archive: HabitArchive) throws {
        guard archive.version == 2 else { throw ArchiveValidationError.unsupportedVersion }
        guard archive.habits.count <= ArchiveLimits.maxHabits,
              archive.entries.count <= ArchiveLimits.maxEntries else { throw ArchiveValidationError.resourceLimitExceeded }
        var habitIDs = Set<UUID>()
        for habit in archive.habits {
            guard habit.isValid, habitIDs.insert(habit.id).inserted else { throw ArchiveValidationError.invalidData }
        }
        var entryIDs = Set<UUID>()
        var entryKeys = Set<EntryKey>()
        for entry in archive.entries {
            guard habitIDs.contains(entry.habitID), entryIDs.insert(entry.id).inserted,
                  entryKeys.insert(EntryKey(habitID: entry.habitID, day: entry.day)).inserted,
                  entry.value.isFinite, entry.value >= 0, entry.target.isFinite, entry.target > 0,
                  (entry.kind == .checkIn ? entry.checkIn != nil : entry.checkIn == nil),
                  ArchiveLimits.validText(entry.unit, maximum: ArchiveLimits.maxUnitScalars),
                  entry.day.ordinal != nil else { throw ArchiveValidationError.invalidData }
        }
    }

    public func save(_ archive: HabitArchive) throws {
        // Validate and enforce the encoded byte limit before touching the existing file or directory.
        let data = try Self.encode(archive)
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}

public enum ArchiveValidationError: LocalizedError {
    case unsupportedVersion
    case invalidData
    case resourceLimitExceeded
    case legacyCalendarRequired
    case ambiguousLegacyCalendar

    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion: "This backup uses a format this version of Day in Ink doesn’t support."
        case .invalidData: "This file contains invalid or inconsistent Day in Ink data."
        case .resourceLimitExceeded: "This backup exceeds Day in Ink’s supported file, record or text limits."
        case .legacyCalendarRequired: "Choose the calendar and timezone originally used for this older backup before migrating its day history."
        case .ambiguousLegacyCalendar: "This older backup omitted era, cycle or leap-month information required by its calendar. Its day history cannot be safely migrated; the original file has not been changed."
        }
    }
}
