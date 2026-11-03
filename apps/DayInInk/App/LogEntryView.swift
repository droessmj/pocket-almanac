import SwiftUI
import HabitKit

struct LogEntryView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let habit: Habit
    let date: Date
    @State private var value = "0"
    @State private var checkIn: CheckIn?

    private var existing: HabitEntry? { store.entry(habit, on: date) }
    private var kind: HabitKind { existing?.kind ?? habit.kind }
    private var goal: Double { existing?.target ?? habit.target }
    private var unit: String { existing?.unit ?? habit.unit }
    private var valid: Bool {
        kind == .checkIn ? checkIn != nil : (parseAmount(value).map { $0 >= 0 } ?? false)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        HabitIcon(habit: habit, size: 52)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(habit.name).font(DayInInkTheme.handwriting(24, relativeTo: .headline))
                            Text(date.formatted(date: .complete, time: .omitted))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 6)
                }

                if kind == .checkIn {
                    Section {
                        checkInButton(.passed, title: "Passed", subtitle: "I kept my promise", icon: "checkmark.circle.fill", color: habit.color.tint)
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
                        HStack(spacing: 12) {
                            ForEach([1.0, 2.0, 5.0], id: \.self) { multiplier in
                                Button("+\(amount(habit.step * multiplier))") {
                                    value = editableAmount((parseAmount(value) ?? 0) + habit.step * multiplier)
                                }
                                .buttonStyle(.bordered).tint(habit.color.tint).frame(maxWidth: .infinity)
                            }
                        }.padding(.vertical, 6)
                    } header: { Text("Build your progress") }
                    footer: { Text("Daily goal: \(amount(goal)) \(unit). Enter your total for this day, or use a quick-add button.") }
                }

                if store.archive.entry(for: habit, on: date) != nil {
                    Section {
                        Button("Clear this day", role: .destructive) {
                            if store.clear(habit, on: date) { dismiss() }
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
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).bold().disabled(!valid) }
            }
            .onAppear {
                value = editableAmount(existing?.value ?? 0)
                checkIn = existing?.checkIn
            }
        }
        .presentationDetents(kind == .checkIn ? [.large] : [.medium, .large])
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
        guard valid else { return }
        if store.record(habit, on: date, value: kind == .progress ? parseAmount(value) : nil, checkIn: checkIn) {
            dismiss()
        }
    }
}
