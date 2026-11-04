import SwiftUI
import HabitKit

struct LogEntryView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let habit: Habit
    @Environment(\.calendar) private var calendar
    private let day: HabitDay
    private var date: Date? { day.date(calendar: calendar) }

    init(habit: Habit, day: HabitDay) {
        self.habit = habit
        self.day = day
    }
    @State private var value = "0"
    @State private var checkIn: CheckIn?
    @State private var errorMessage: String?
    @State private var saving = false

    private var existing: HabitEntry? { date.flatMap { store.entry(habit, on: $0) } }
    private var kind: HabitKind { existing?.kind ?? habit.kind }
    private var goal: Decimal { existing?.target ?? habit.target }
    private var unit: String { existing?.unit ?? habit.unit }
    private var valid: Bool {
        date != nil && (kind == .checkIn ? checkIn != nil : (parseAmount(value).map { $0 >= 0 } ?? false))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        HabitIcon(habit: habit, size: 52)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(habit.name).font(DayInInkTheme.handwriting(24, relativeTo: .headline))
                            Text(date.map { habitDateLabel($0, format: Date.FormatStyle(date: .complete, time: .omitted)) } ?? "This day is unavailable in your current time zone.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 6)
                }

                if kind == .checkIn {
                    Section {
                        checkInButton(.passed, title: "Passed", subtitle: "I kept my promise", icon: "checkmark.circle.fill", color: habit.color.textColor)
                        checkInButton(.failed, title: "Failed", subtitle: "A fresh start tomorrow", icon: "xmark.circle.fill", color: DayInInkTheme.secondary)
                    } header: { Text("How did it go?") }
                    footer: {
                        Text(habit.defaultPassed ? "Unrecorded pass/fail days count as passed."
                                                 : "Unrecorded pass/fail days count as failed. Mark a pass when you complete it.")
                    }
                } else {
                    Section {
                        HStack {
                            Text("Daily total")
                            TextField("0", text: $value).keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing).accessibilityLabel("Daily total")
                            Text(unit).foregroundStyle(.secondary)
                        }
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 12) { quickAdds }
                            VStack(spacing: 12) { quickAdds }
                        }.padding(.vertical, 6)
                    } header: { Text("Build your progress") }
                    footer: { Text("Daily goal: \(amount(goal)) \(unit). Enter your total using your region’s decimal separator, without grouping separators, or use a quick-add button.") }
                }

                if let date, store.archive.entry(for: habit, on: date) != nil {
                    Section {
                        Button("Clear this day", role: .destructive) {
                            submit { try await store.clear(habit, on: date) }
                        }
                    } footer: {
                        Text(habit.kind == .checkIn
                             ? "Clearing a day restores its default \(habit.defaultPassed ? "passed" : "failed") result."
                             : "Clearing a day returns it to unrecorded.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background { PaperSurface().ignoresSafeArea() }
            .navigationTitle("Daily check-in").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).bold().disabled(!valid || saving) }
            }
            .task {
                value = editableAmount(existing?.value ?? 0)
                checkIn = existing?.checkIn
            }
            .disabled(saving)
            .interactiveDismissDisabled(saving)
            .mutationError($errorMessage)
        }
        .presentationDetents(kind == .checkIn ? [.large] : [.medium, .large])
    }

    private var quickAdds: some View {
        ForEach([1, 2, 5], id: \.self) { multiplier in
            let increment = try? HabitAmount.multiplying(habit.step, by: multiplier)
            Button(increment.map { "+\(amount($0))" } ?? "Amount unavailable") {
                guard let current = parseAmount(value), let increment else { return }
                do {
                    value = editableAmount(try HabitAmount.adding(current, increment))
                } catch { errorMessage = error.localizedDescription }
            }
            .accessibilityIdentifier("log-add-\(multiplier)")
            .accessibilityLabel(increment.map { "Add \(spokenAmount($0)) \(unit)" } ?? "Quick-add amount exceeds numeric limits")
            .buttonStyle(.bordered).tint(habit.color.textColor).frame(maxWidth: .infinity)
            .disabled(parseAmount(value) == nil || increment == nil)
        }
    }

    private func checkInButton(_ option: CheckIn, title: String, subtitle: String, icon: String, color: Color) -> some View {
        Button { checkIn = option } label: {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.title2).foregroundStyle(color)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(DayInInkTheme.handwriting(23, relativeTo: .headline)).foregroundStyle(DayInInkTheme.ink)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if checkIn == option { Image(systemName: "checkmark").foregroundStyle(color).bold() }
            }
            .padding(.vertical, 6).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("checkin-\(option.rawValue)")
        .accessibilityAddTraits(checkIn == option ? .isSelected : [])
    }

    private func save() {
        guard valid, let date else { return }
        submit {
            try await store.record(habit, on: date, value: kind == .progress ? parseAmount(value) : nil, checkIn: checkIn)
        }
    }

    private func submit(_ operation: @escaping @MainActor () async throws -> Void) {
        guard !saving else { return }
        saving = true
        Task {
            defer { saving = false }
            do {
                try await operation()
                dismiss()
            } catch { errorMessage = error.localizedDescription }
        }
    }
}
