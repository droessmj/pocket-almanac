import Foundation

public struct ArchiveFile: Sendable {
    public let url: URL

    public init(url: URL) { self.url = url }

    public func load() throws -> HabitArchive? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try Self.decode(Data(contentsOf: url))
    }

    /// The backup format is also the on-device format, preserving IDs and historical goal snapshots.
    public static func decode(_ data: Data) throws -> HabitArchive {
        let archive = try JSONDecoder().decode(HabitArchive.self, from: data)
        try validate(archive)
        return archive
    }

    public static func encode(_ archive: HabitArchive) throws -> Data {
        try validate(archive)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(archive)
    }

    private static func validate(_ archive: HabitArchive) throws {
        guard archive.version == 1 else { throw ArchiveValidationError.unsupportedVersion }
        let habits = Dictionary(archive.habits.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        guard archive.habits.allSatisfy({ $0.isValid && $0.createdAt.timeIntervalSinceReferenceDate.isFinite }),
              Set(archive.habits.map(\.id)).count == archive.habits.count,
              Set(archive.entries.map(\.id)).count == archive.entries.count,
              Set(archive.entries.map { "\($0.habitID)-\($0.day.year)-\($0.day.month)-\($0.day.day)" }).count == archive.entries.count,
              archive.entries.allSatisfy({ entry in
                  guard habits[entry.habitID] != nil,
                        entry.value.isFinite, entry.value >= 0, entry.target.isFinite, entry.target > 0,
                        (entry.kind == .checkIn ? entry.checkIn != nil : entry.checkIn == nil) else { return false }
                  // Round-trip components: Calendar.date normalizes impossible dates such as February 30.
                  let calendar = Calendar.current
                  guard let date = calendar.date(from: DateComponents(year: entry.day.year, month: entry.day.month,
                                                                      day: entry.day.day)) else { return false }
                  return HabitDay(date, calendar: calendar) == entry.day
              }) else { throw ArchiveValidationError.invalidData }
    }

    public func save(_ archive: HabitArchive) throws {
        // Encode and validate before touching the existing file or directory.
        let data = try Self.encode(archive)
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}

public enum ArchiveValidationError: LocalizedError {
    case unsupportedVersion
    case invalidData

    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion: "This backup uses a format this version of Day in Ink doesn’t support."
        case .invalidData: "This file contains invalid or inconsistent Day in Ink data."
        }
    }
}
