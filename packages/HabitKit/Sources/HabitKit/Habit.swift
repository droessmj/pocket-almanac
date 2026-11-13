import Foundation

public enum HabitKind: String, Codable, CaseIterable, Sendable {
    case checkIn, progress
}

public enum HabitColor: String, Codable, CaseIterable, Sendable {
    case blue, lavender, amber, mint, coral, rose
}

/// Decimal arithmetic must reject precision loss instead of silently dropping a quick-add.
public enum HabitAmount {
    public static func adding(_ total: Decimal, _ increment: Decimal) throws -> Decimal {
        var total = total, increment = increment, result = Decimal()
        guard NSDecimalAdd(&result, &total, &increment, .plain) == .noError, !result.isNaN else {
            throw CalculationError.unrepresentable
        }
        return result
    }

    public static func multiplying(_ amount: Decimal, by multiplier: Int) throws -> Decimal {
        var amount = amount, multiplier = Decimal(multiplier), result = Decimal()
        guard NSDecimalMultiply(&result, &amount, &multiplier, .plain) == .noError, !result.isNaN else {
            throw CalculationError.unrepresentable
        }
        return result
    }

    private enum CalculationError: LocalizedError {
        case unrepresentable

        var errorDescription: String? {
            "This calculation exceeds the supported numeric precision or range. Your previous total has been kept."
        }
    }
}

public struct Habit: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var emoji: String
    public var color: HabitColor
    public var kind: HabitKind
    public var target: Decimal
    public var step: Decimal
    public var unit: String
    public var createdAt: Date
    /// The creation-day identity is captured once and never reinterpreted after timezone travel.
    public var startDay: HabitDay
    public var isArchived: Bool
    public var defaultPassed: Bool

    public init(id: UUID = UUID(), name: String, emoji: String, color: HabitColor,
                kind: HabitKind, target: Decimal = 1, step: Decimal = 1, unit: String = "",
                createdAt: Date = Date(), isArchived: Bool = false, defaultPassed: Bool = true,
                startDay: HabitDay? = nil, calendar: Calendar = .current) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.color = color
        self.kind = kind
        self.target = kind == .checkIn ? 1 : target
        self.step = kind == .checkIn ? 1 : step
        self.unit = kind == .checkIn ? "" : unit
        self.createdAt = createdAt
        self.startDay = startDay ?? HabitDay(createdAt, calendar: calendar)
        self.isArchived = isArchived
        self.defaultPassed = defaultPassed
    }

    public var isValid: Bool {
        ArchiveLimits.validText(name, maximum: ArchiveLimits.maxNameScalars, required: true) &&
        ArchiveLimits.validText(emoji, maximum: ArchiveLimits.maxEmojiScalars, required: true) &&
        ArchiveLimits.validText(unit, maximum: ArchiveLimits.maxUnitScalars) &&
        ArchiveLimits.contains(createdAt) && startDay.ordinal != nil &&
        !target.isNaN && target > 0 && !step.isNaN && step > 0
    }

    /// Resolve the stable civil start day in the viewer's timezone, not the creation timestamp.
    public func startDate(calendar: Calendar = .current) -> Date? {
        startDay.date(calendar: calendar)
    }

    /// A clock rollback may put creation after today; never form an inverted picker range.
    public func historyDateRange(through now: Date = Date(), calendar: Calendar = .current) -> ClosedRange<Date>? {
        guard ArchiveLimits.contains(createdAt), ArchiveLimits.contains(now), startDay.ordinal != nil else { return nil }
        let calendar = HabitDay.localCalendar(calendar)
        // Calendar normalizes a skipped civil date forward to its first representable day.
        guard let resolved = calendar.date(from: DateComponents(year: startDay.year, month: startDay.month,
                                                                 day: startDay.day)) else { return nil }
        let start = calendar.startOfDay(for: resolved)
        guard HabitDay(start, calendar: calendar) >= startDay, start <= now else { return nil }
        return start...now
    }
}

/// Gregorian local day components: calendar preferences never change identity, but timezone and DST do.
public struct HabitDay: Codable, Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init(_ date: Date, calendar: Calendar = .current) {
        let parts = ArchiveLimits.contains(date)
            ? Self.localCalendar(calendar).dateComponents([.year, .month, .day], from: date)
            : DateComponents()
        year = parts.year ?? 0
        month = parts.month ?? 0
        day = parts.day ?? 0
    }

    static func localCalendar(_ source: Calendar) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = source.timeZone
        return calendar
    }

    /// Convert this Gregorian civil key to the beginning of that day in the supplied timezone.
    public func date(calendar: Calendar = .current) -> Date? {
        guard ordinal != nil else { return nil }
        let calendar = Self.localCalendar(calendar)
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)) else { return nil }
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard parts.year == year, parts.month == month, parts.day == day else { return nil }
        return calendar.startOfDay(for: date)
    }

    /// A civil-day ordinal, not elapsed local seconds (which vary across DST).
    var ordinal: Int? {
        guard ArchiveLimits.supportedYears.contains(year), (1...12).contains(month), (1...31).contains(day) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
              Self(date, calendar: calendar) == self else { return nil }
        return Int(date.timeIntervalSinceReferenceDate / 86_400)
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
    public var value: Decimal
    public var checkIn: CheckIn?
    public var target: Decimal
    public var kind: HabitKind
    public var unit: String

    public init(habit: Habit, date: Date, value: Decimal = 0, checkIn: CheckIn? = nil,
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
        guard !target.isNaN, target > 0, !value.isNaN else { return 0 }
        if value <= 0 { return 0 }
        if value >= target { return 1 }
        return NSDecimalNumber(decimal: value).doubleValue / NSDecimalNumber(decimal: target).doubleValue
    }
}

public struct HabitArchive: Codable, Equatable, Sendable {
    public var version = 3
    public var habits: [Habit]
    private var storedEntries: [HabitEntry]
    /// Derived, value-semantic indexes; never encoded or included in equality.
    private var entryIndices: [UUID: [Int: Int]] = [:]

    public var entries: [HabitEntry] {
        get { storedEntries }
        set {
            storedEntries = newValue
            rebuildEntryIndices()
        }
        _modify {
            defer { rebuildEntryIndices() }
            yield &storedEntries
        }
    }

    public init(habits: [Habit] = [], entries: [HabitEntry] = []) {
        self.habits = habits
        storedEntries = entries
        rebuildEntryIndices()
    }

    private mutating func rebuildEntryIndices() {
        entryIndices.removeAll(keepingCapacity: true)
        for index in storedEntries.indices {
            let entry = storedEntries[index]
            guard let ordinal = entry.day.ordinal else { continue }
            if entryIndices[entry.habitID]?[ordinal] == nil {
                entryIndices[entry.habitID, default: [:]][ordinal] = index
            }
        }
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.version == rhs.version && lhs.habits == rhs.habits && lhs.storedEntries == rhs.storedEntries
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(version, forKey: .version)
        try values.encode(habits, forKey: .habits)
        try values.encode(storedEntries, forKey: .entries)
    }

    private enum CodingKeys: String, CodingKey { case version, habits, entries }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        version = try values.decode(Int.self, forKey: .version)
        guard version == 3 else { throw ArchiveValidationError.unsupportedVersion }
        var habitValues = try values.nestedUnkeyedContainer(forKey: .habits)
        habits = []
        while !habitValues.isAtEnd {
            guard habits.count < ArchiveLimits.maxHabits else { throw ArchiveValidationError.resourceLimitExceeded }
            habits.append(try habitValues.decode(Habit.self))
        }
        var entryValues = try values.nestedUnkeyedContainer(forKey: .entries)
        storedEntries = []
        while !entryValues.isAtEnd {
            guard storedEntries.count < ArchiveLimits.maxEntries else { throw ArchiveValidationError.resourceLimitExceeded }
            storedEntries.append(try entryValues.decode(HabitEntry.self))
        }
        rebuildEntryIndices()
    }

    private func entryIndex(for habitID: UUID, day: HabitDay) -> Int? {
        guard let ordinal = day.ordinal else { return nil }
        return entryIndices[habitID]?[ordinal]
    }

    public func entry(for habit: Habit, on date: Date, calendar: Calendar = .current) -> HabitEntry? {
        let day = HabitDay(date, calendar: calendar)
        guard habit.startDay.ordinal != nil, day >= habit.startDay,
              let index = entryIndex(for: habit.id, day: day) else { return nil }
        return storedEntries[index]
    }

    /// Resolve an unrecorded pass/fail day using its default without writing synthetic history.
    public func effectiveEntry(for habit: Habit, on date: Date, calendar: Calendar = .current,
                               now: Date = Date()) -> HabitEntry? {
        let day = HabitDay(date, calendar: calendar)
        guard habit.startDay.ordinal != nil, day >= habit.startDay,
              day <= HabitDay(now, calendar: calendar) else { return nil }
        if let recorded = entry(for: habit, on: date, calendar: calendar) { return recorded }
        guard habit.kind == .checkIn else { return nil }
        return HabitEntry(habit: habit, date: date, checkIn: habit.defaultPassed ? .passed : .failed,
                          calendar: calendar)
    }

    /// Only explicit check-ins are stored; zero remains a recorded progress value.
    @discardableResult
    public mutating func record(_ habit: Habit, on date: Date, value: Decimal? = nil,
                                checkIn: CheckIn? = nil, calendar: Calendar = .current,
                                now: Date = Date()) -> Bool {
        guard let current = habits.first(where: { $0.id == habit.id }) else { return false }
        let day = HabitDay(date, calendar: calendar)
        let index = entryIndex(for: habit.id, day: day)
        let kind = index.map { storedEntries[$0].kind } ?? current.kind
        guard ArchiveLimits.contains(date), ArchiveLimits.contains(now),
              let ordinal = day.ordinal, current.isValid,
              day <= HabitDay(now, calendar: calendar), day >= current.startDay,
              value == nil || (!value!.isNaN && value! >= 0),
              (kind == .progress && value != nil && checkIn == nil) ||
              (kind == .checkIn && checkIn != nil && value == nil) else { return false }
        if let index {
            // Preserve the original goal, unit and tracking mode for this day.
            if kind == .checkIn {
                storedEntries[index].checkIn = checkIn
            } else {
                storedEntries[index].value = value!
            }
        } else {
            entryIndices[habit.id, default: [:]][ordinal] = storedEntries.count
            storedEntries.append(HabitEntry(habit: current, date: date, value: value ?? 0,
                                            checkIn: checkIn, calendar: calendar))
        }
        return true
    }

    public mutating func clear(_ habit: Habit, on date: Date, calendar: Calendar = .current) {
        let day = HabitDay(date, calendar: calendar)
        guard let index = entryIndex(for: habit.id, day: day) else { return }
        storedEntries.remove(at: index)
        rebuildEntryIndices()
    }

    /// Work is bounded by recorded entries, not the number of implicit days since creation.
    public func streak(for habit: Habit, through date: Date = Date(), calendar: Calendar = .current,
                       now: Date = Date()) -> Int {
        let calendar = HabitDay.localCalendar(calendar)
        let end = HabitDay(date, calendar: calendar)
        guard let first = habit.startDay.ordinal,
              var last = end.ordinal, last >= first,
              end <= HabitDay(now, calendar: calendar) else { return 0 }
        let indices = entryIndices[habit.id] ?? [:]
        let endEntry = indices[last].map { storedEntries[$0] }
        let implicitPass = habit.kind == .checkIn && habit.defaultPassed
        let endComplete = endEntry?.isComplete ?? implicitPass
        // An unfinished current day doesn't end yesterday's streak; an explicit failure does.
        if !endComplete, end == HabitDay(now, calendar: calendar), endEntry?.checkIn != .failed {
            last -= 1
        }
        guard last >= first else { return 0 }
        if implicitPass {
            var boundary = first - 1
            for (ordinal, index) in indices where ordinal >= first && ordinal <= last {
                if !storedEntries[index].isComplete {
                    boundary = max(boundary, ordinal)
                }
            }
            return last - boundary
        }
        var expected = last
        while expected >= first, let index = indices[expected], storedEntries[index].isComplete {
            expected -= 1
        }
        return last - expected
    }

    public func isComplete(_ habit: Habit, on date: Date, calendar: Calendar = .current) -> Bool {
        effectiveEntry(for: habit, on: date, calendar: calendar)?.isComplete ?? false
    }

    public func samples(for habit: Habit, days: Int, through end: Date = Date(),
                        calendar: Calendar = .current) -> [HabitSample] {
        guard days > 0 else { return [] }
        let calendar = HabitDay.localCalendar(calendar)
        let end = calendar.startOfDay(for: end)
        guard habit.startDay.ordinal != nil else { return [] }
        return (0..<days).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: end),
                  HabitDay(date, calendar: calendar) >= habit.startDay else { return nil }
            let recorded = entry(for: habit, on: date, calendar: calendar)
            return HabitSample(date: date, entry: effectiveEntry(for: habit, on: date, calendar: calendar),
                               isDefault: recorded == nil && habit.kind == .checkIn)
        }
    }

    public static func starterHabits(now: Date = Date()) -> Self {
        Self(habits: [
            Habit(name: "Walk", emoji: "🚶", color: .blue, kind: .progress, target: 10000, step: 1000, unit: "steps", createdAt: now),
            Habit(name: "Drink Water", emoji: "💧", color: .mint, kind: .progress, target: 8, step: 1, unit: "glasses", createdAt: now),
            Habit(name: "Workout", emoji: "🔥", color: .coral, kind: .checkIn, createdAt: now)
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
