import SwiftUI
import HabitKit

struct HabitEditor: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    private let original: Habit?
    @State private var name: String
    @State private var emoji: String
    @State private var color: HabitColor
    @State private var kind: HabitKind
    @State private var defaultPassed: Bool
    @State private var target: String
    @State private var step: String
    @State private var unit: String

    private let emojis = ["🚶", "🔥", "💡", "🍞", "📖", "💧", "🧘", "🏃", "🌱", "💤", "🎨", "💪"]

    init(habit: Habit? = nil) {
        original = habit
        _name = State(initialValue: habit?.name ?? "")
        _emoji = State(initialValue: habit?.emoji ?? "🌱")
        _color = State(initialValue: habit?.color ?? .lavender)
        _kind = State(initialValue: habit?.kind ?? .checkIn)
        _defaultPassed = State(initialValue: habit?.defaultPassed ?? true)
        _target = State(initialValue: editableAmount(habit?.target ?? 30))
        _step = State(initialValue: editableAmount(habit?.step ?? 5))
        _unit = State(initialValue: habit?.unit ?? "min")
    }

    private var targetValue: Double? { parseAmount(target) }
    private var stepValue: Double? { parseAmount(step) }
    private var valid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        name.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars.count <= ArchiveLimits.maxNameScalars &&
        !emoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        emoji.unicodeScalars.count <= ArchiveLimits.maxEmojiScalars &&
        unit.trimmingCharacters(in: .whitespacesAndNewlines).unicodeScalars.count <= ArchiveLimits.maxUnitScalars &&
        (kind == .checkIn || ((targetValue ?? 0) > 0 && (stepValue ?? 0) > 0 && !unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        Text(emoji).font(.system(size: 36)).frame(width: 68, height: 68)
                            .background(color.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 20))
                        VStack(alignment: .leading, spacing: 5) {
                            Text("One small promise").font(DaymarkTheme.handwriting(24, relativeTo: .headline))
                            Text("Build a routine that feels like you.").font(.caption).foregroundStyle(.secondary)
                        }
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 8)
                    TextField("Habit name", text: $name).accessibilityLabel("Habit name")
                }

                Section("Make it yours") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(emojis, id: \.self) { symbol in
                            Button { emoji = symbol } label: {
                                Text(symbol).font(.title2).frame(maxWidth: .infinity).frame(height: 42)
                                    .background(emoji == symbol ? color.tint.opacity(0.16) : .clear, in: RoundedRectangle(cornerRadius: 12))
                            }.buttonStyle(.plain).accessibilityLabel("Choose \(symbol)")
                                .accessibilityAddTraits(emoji == symbol ? .isSelected : [])
                        }
                    }.padding(.vertical, 8)
                    HStack {
                        Text("Custom emoji")
                        Spacer()
                        TextField("🌱", text: $emoji).multilineTextAlignment(.trailing).frame(width: 70)
                            .onChange(of: emoji) { _, value in emoji = String(value.prefix(1)) }
                            .accessibilityLabel("Custom emoji")
                    }
                    HStack {
                        ForEach(HabitColor.allCases, id: \.self) { option in
                            Button { color = option } label: {
                                Circle().fill(option.tint).frame(width: 30, height: 30)
                                    .overlay {
                                        if color == option {
                                            Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                                        }
                                    }.frame(maxWidth: .infinity).frame(height: 44)
                            }.buttonStyle(.plain).accessibilityLabel(option.label)
                                .accessibilityAddTraits(color == option ? .isSelected : [])
                        }
                    }
                }

                Section {
                    Picker("Tracking", selection: $kind) {
                        Text("Pass / fail").tag(HabitKind.checkIn)
                        Text("Build progress").tag(HabitKind.progress)
                    }
                    .pickerStyle(.segmented)
                    if kind == .checkIn {
                        Text("Daily default").font(.subheadline)
                        Picker("Daily default", selection: $defaultPassed) {
                            Text("Passed").tag(true)
                            Text("Failed").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("default-result")
                    } else {
                        HStack {
                            Text("Daily goal")
                            TextField("30", text: $target).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                .accessibilityLabel("Daily goal")
                        }
                        HStack {
                            Text("Unit")
                            TextField("min, steps, pages…", text: $unit).multilineTextAlignment(.trailing)
                                .accessibilityLabel("Progress unit")
                        }
                        HStack {
                            Text("Quick-add amount")
                            TextField("5", text: $step).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                                .accessibilityLabel("Quick-add amount")
                        }
                    }
                } header: { Text("How you’ll track it") }
                footer: {
                    Text(kind == .checkIn
                         ? (defaultPassed ? "Each day starts as passed. Mark a failure whenever needed."
                                          : "Each day starts as failed. Mark a pass when you complete it.")
                         : "Tap + on a habit to add progress. You can also enter an exact daily total. Goal changes apply to days you haven’t logged yet.")
                    if original != nil {
                        Text("Tracking changes apply to unrecorded days. Recorded days keep their original tracking type, goal, and unit. Clear a recorded day to use the new type.")
                        if kind == .checkIn {
                            Text("Changing the daily default updates unrecorded days, including past days. Explicit passes and failures stay as you logged them.")
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollContentBackground(.hidden)
            .background { PaperSurface().ignoresSafeArea() }
            .navigationTitle(original == nil ? "A new beginning" : "Edit habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(original == nil ? "Create" : "Save", action: save).bold().disabled(!valid)
                }
            }
        }
    }

    private func save() {
        guard valid else { return }
        let habit = Habit(id: original?.id ?? UUID(), name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                          emoji: emoji, color: color, kind: kind, target: targetValue ?? 1,
                          step: stepValue ?? 1, unit: unit.trimmingCharacters(in: .whitespacesAndNewlines),
                          createdAt: original?.createdAt ?? Date(), isArchived: original?.isArchived ?? false,
                          defaultPassed: defaultPassed)
        if store.save(habit) { dismiss() }
    }
}

func parseAmount(_ text: String) -> Double? {
    let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: Locale.current.decimalSeparator ?? ".", with: ".")
    guard let value = Double(normalized), value.isFinite else { return nil }
    return value
}

/// Double's shortest round-trippable representation, localized only for the decimal separator.
func editableAmount(_ value: Double, locale: Locale = .current) -> String {
    String(value).replacingOccurrences(of: ".", with: locale.decimalSeparator ?? ".")
}
