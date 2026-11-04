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

    public func load() throws -> HabitArchive? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Self.read(from: url)
    }

    /// Reads at most the byte limit plus one sentinel byte, including files that grow during reading.
    /// No unbounded Data(contentsOf:) allocation occurs before validation.
    public static func read(from url: URL) throws -> HabitArchive {
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
        return try decode(data)
    }

    /// Only the complete current-state schema is accepted; older backups are never inferred or migrated.
    public static func decode(_ data: Data) throws -> HabitArchive {
        guard data.count <= ArchiveLimits.maxBytes else { throw ArchiveValidationError.resourceLimitExceeded }
        let archive = try JSONDecoder().decode(HabitArchive.self, from: data)
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
        guard archive.version == 3 else { throw ArchiveValidationError.unsupportedVersion }
        guard archive.habits.count <= ArchiveLimits.maxHabits,
              archive.entries.count <= ArchiveLimits.maxEntries else { throw ArchiveValidationError.resourceLimitExceeded }
        var habitStarts: [UUID: HabitDay] = [:]
        for habit in archive.habits {
            guard habit.isValid, habitStarts[habit.id] == nil else { throw ArchiveValidationError.invalidData }
            habitStarts[habit.id] = habit.startDay
        }
        var entryIDs = Set<UUID>()
        var entryKeys = Set<EntryKey>()
        for entry in archive.entries {
            guard let startDay = habitStarts[entry.habitID], entry.day >= startDay,
                  entryIDs.insert(entry.id).inserted,
                  entryKeys.insert(EntryKey(habitID: entry.habitID, day: entry.day)).inserted,
                  !entry.value.isNaN, entry.value >= 0, !entry.target.isNaN, entry.target > 0,
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

    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion: "This backup uses a format this version of Day in Ink doesn’t support."
        case .invalidData: "This file contains invalid or inconsistent Day in Ink data."
        case .resourceLimitExceeded: "This backup exceeds Day in Ink’s supported file, record or text limits."
        }
    }
}
