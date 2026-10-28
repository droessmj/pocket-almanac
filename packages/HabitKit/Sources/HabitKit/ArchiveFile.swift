import Foundation

public struct ArchiveFile: Sendable {
    public let url: URL

    public init(url: URL) { self.url = url }

    public func load() throws -> HabitArchive? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let archive = try JSONDecoder().decode(HabitArchive.self, from: Data(contentsOf: url))
        guard archive.version == 1, archive.habits.allSatisfy(\.isValid),
              Set(archive.habits.map(\.id)).count == archive.habits.count,
              Set(archive.entries.map { "\($0.habitID)-\($0.day.year)-\($0.day.month)-\($0.day.day)" }).count == archive.entries.count,
              archive.entries.allSatisfy({ entry in
                  entry.value.isFinite && entry.value >= 0 && entry.target.isFinite && entry.target > 0 &&
                  archive.habits.contains(where: { $0.id == entry.habitID })
              }) else { throw CocoaError(.fileReadCorruptFile) }
        return archive
    }

    public func save(_ archive: HabitArchive) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(archive).write(to: url, options: .atomic)
    }
}
