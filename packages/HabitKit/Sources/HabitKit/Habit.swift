import Foundation

public enum HabitKind: String, Codable, CaseIterable, Sendable {
    case checkIn, progress
}

public enum HabitColor: String, Codable, CaseIterable, Sendable {
    case blue, lavender, amber, mint, coral, rose
}

public struct Habit: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var emoji: String
    public var color: HabitColor
    public var kind: HabitKind
    public var target: Double
    public var step: Double
    public var unit: String
    public var createdAt: Date
    public var isArchived: Bool
    public var defaultPassed: Bool

    public init(id: UUID = UUID(), name: String, emoji: String, color: HabitColor,
                kind: HabitKind, target: Double = 1, step: Double = 1, unit: String = "",
                createdAt: Date = Date(), isArchived: Bool = false, defaultPassed: Bool = true) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.color = color
        self.kind = kind
        self.target = kind == .checkIn ? 1 : target
        self.step = kind == .checkIn ? 1 : step
        self.unit = kind == .checkIn ? "" : unit
        self.createdAt = createdAt
        self.isArchived = isArchived
        self.defaultPassed = defaultPassed
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, emoji, color, kind, target, step, unit, createdAt, isArchived, defaultPassed
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        emoji = try values.decode(String.self, forKey: .emoji)
        color = try values.decode(HabitColor.self, forKey: .color)
        kind = try values.decode(HabitKind.self, forKey: .kind)
        target = try values.decode(Double.self, forKey: .target)
        step = try values.decode(Double.self, forKey: .step)
        unit = try values.decode(String.self, forKey: .unit)
        createdAt = try values.decode(Date.self, forKey: .createdAt)
        isArchived = try values.decode(Bool.self, forKey: .isArchived)
        // Older archives implicitly passed every unrecorded pass/fail day.
        defaultPassed = try values.decodeIfPresent(Bool.self, forKey: .defaultPassed) ?? true
    }

    public var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !emoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        target.isFinite && target > 0 && step.isFinite && step > 0
    }
}

/// Components represent a local calendar day, independent of UTC offsets and DST.
public struct HabitDay: Codable, Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(_ date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        year = parts.year!
        month = parts.month!
        day = parts.day!
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}

public enum CheckIn: String, Codable, Sendable {
    case passed, failed
}

/// A goal snapshot keeps historical results stable when a habit's goal is edited.
public struct HabitEntry: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var habitID: UUID
    public var day: HabitDay
    public var value: Double
    public var checkIn: CheckIn?
    public var target: Double
    public var kind: HabitKind
    public var unit: String

    public init(habit: Habit, date: Date, value: Double = 0, checkIn: CheckIn? = nil,
                calendar: Calendar = .current) {
        id = UUID()
        habitID = habit.id
        day = HabitDay(date, calendar: calendar)
        self.value = value
        self.checkIn = checkIn
        target = habit.target
        kind = habit.kind
        unit = habit.unit
    }

    public var isComplete: Bool {
        kind == .checkIn ? checkIn == .passed : value >= target
    }

    public var fraction: Double {
        if kind == .checkIn { return isComplete ? 1 : 0 }
        guard target > 0 else { return 0 }
        return min(max(value / target, 0), 1)
    }
}

public struct HabitArchive: Codable, Equatable, Sendable {
    public var version = 1
    public var habits: [Habit]
    public var entries: [HabitEntry]

    public init(habits: [Habit] = [], entries: [HabitEntry] = []) {
        self.habits = habits
        self.entries = entries
    }

    public func entry(for habit: Habit, on date: Date, calendar: Calendar = .current) -> HabitEntry? {
        let day = HabitDay(date, calendar: calendar)
        return entries.first { $0.habitID == habit.id && $0.day == day }
    }

    /// Resolve an unrecorded pass/fail day using its default without writing synthetic history.
    public func effectiveEntry(for habit: Habit, on date: Date, calendar: Calendar = .current,
                               now: Date = Date()) -> HabitEntry? {
        let day = HabitDay(date, calendar: calendar)
        guard day >= HabitDay(habit.createdAt, calendar: calendar),
              day <= HabitDay(now, calendar: calendar) else { return nil }
        if let recorded = entry(for: habit, on: date, calendar: calendar) { return recorded }
        guard habit.kind == .checkIn else { return nil }
        return HabitEntry(habit: habit, date: date, checkIn: habit.defaultPassed ? .passed : .failed,
                          calendar: calendar)
    }

    /// Only explicit check-ins are stored; zero remains a recorded progress value.
    public mutating func record(_ habit: Habit, on date: Date, value: Double? = nil,
                                checkIn: CheckIn? = nil, calendar: Calendar = .current,
                                now: Date = Date()) {
        let day = HabitDay(date, calendar: calendar)
        let kind = entry(for: habit, on: date, calendar: calendar)?.kind ?? habit.kind
        guard day <= HabitDay(now, calendar: calendar),
              day >= HabitDay(habit.createdAt, calendar: calendar),
              habits.contains(where: { $0.id == habit.id }),
              value == nil || (value!.isFinite && value! >= 0),
              (kind == .progress && value != nil) ||
              (kind == .checkIn && checkIn != nil) else { return }
        if let index = entries.firstIndex(where: { $0.habitID == habit.id && $0.day == day }) {
            // Preserve the original goal, unit and tracking mode for this day.
            if entries[index].kind == .checkIn {
                guard let checkIn else { return }
                entries[index].checkIn = checkIn
            } else {
                guard let value else { return }
                entries[index].value = value
            }
        } else {
            entries.append(HabitEntry(habit: habit, date: date, value: value ?? 0,
                                      checkIn: checkIn, calendar: calendar))
        }
    }

    public mutating func clear(_ habit: Habit, on date: Date, calendar: Calendar = .current) {
        let day = HabitDay(date, calendar: calendar)
        entries.removeAll { $0.habitID == habit.id && $0.day == day }
    }

    public func streak(for habit: Habit, through date: Date = Date(), calendar: Calendar = .current) -> Int {
        var cursor = calendar.startOfDay(for: date)
        // An unfinished current day doesn't end yesterday's streak.
        if !isComplete(habit, on: cursor, calendar: calendar), calendar.isDateInToday(date),
           entry(for: habit, on: cursor, calendar: calendar)?.checkIn != .failed {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        var count = 0
        while cursor >= calendar.startOfDay(for: habit.createdAt), isComplete(habit, on: cursor, calendar: calendar) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    public func isComplete(_ habit: Habit, on date: Date, calendar: Calendar = .current) -> Bool {
        effectiveEntry(for: habit, on: date, calendar: calendar)?.isComplete ?? false
    }

    public func samples(for habit: Habit, days: Int, through end: Date = Date(),
                        calendar: Calendar = .current) -> [HabitSample] {
        guard days > 0 else { return [] }
        let end = calendar.startOfDay(for: end)
        let created = calendar.startOfDay(for: habit.createdAt)
        return (0..<days).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: end), date >= created else { return nil }
            return HabitSample(date: date, entry: effectiveEntry(for: habit, on: date, calendar: calendar),
                               isDefault: entry(for: habit, on: date, calendar: calendar) == nil && habit.kind == .checkIn)
        }
    }

    public static func starterHabits(now: Date = Date()) -> Self {
        Self(habits: [
            Habit(name: "Walk", emoji: "🚶", color: .blue, kind: .progress, target: 10000, step: 1000, unit: "steps", createdAt: now),
            Habit(name: "Good workout", emoji: "🔥", color: .coral, kind: .progress, target: 30, step: 10, unit: "min", createdAt: now),
            Habit(name: "Mind clearing", emoji: "💡", color: .lavender, kind: .checkIn, createdAt: now),
            Habit(name: "No snack after dinner", emoji: "🍞", color: .amber, kind: .checkIn, createdAt: now),
            Habit(name: "Read a little", emoji: "📖", color: .rose, kind: .progress, target: 20, step: 5, unit: "pages", createdAt: now),
            Habit(name: "Drink water", emoji: "💧", color: .mint, kind: .progress, target: 8, step: 1, unit: "glasses", createdAt: now)
        ])
    }
}

public struct HabitSample: Identifiable, Sendable {
    public var id: Date { date }
    public let date: Date
    public let entry: HabitEntry?
    public var isDefault = false
    public var fraction: Double { entry?.fraction ?? 0 }
}
