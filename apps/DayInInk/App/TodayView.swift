import SwiftUI
import HabitKit
import UIKit

private enum HabitFilter: String, CaseIterable {
    case all = "All", remaining = "Remaining", completed = "Completed"
}

struct TodayView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.calendar) private var calendar
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var lastToday = HabitDay(Date())
    @State private var selectedDay = HabitDay(Date())
    @State private var filter = HabitFilter.all
    @State private var showCalendar = false
    @State private var logRequest: LogRequest?
    let addHabit: () -> Void

    private var selectedDate: Date {
        get { selectedDay.date(calendar: calendar) ?? calendar.startOfDay(for: Date()) }
        nonmutating set { selectedDay = HabitDay(newValue, calendar: calendar) }
    }
    private var isToday: Bool { selectedDay == HabitDay(Date(), calendar: calendar) }
    private var eligible: [Habit] {
        store.activeHabits.filter { $0.startDay <= selectedDay }
    }
    private var completed: Int {
        eligible.filter { store.archive.isComplete($0, on: selectedDate) }.count
    }
    private var visible: [Habit] {
        eligible.filter { habit in
            switch filter {
            case .all: true
            case .remaining: !store.archive.isComplete(habit, on: selectedDate)
            case .completed: store.archive.isComplete(habit, on: selectedDate)
            }
        }
    }
    private var week: [Date] {
        // Keep the week anchored on Monday.
        let weekday = calendar.component(.weekday, from: selectedDate)
        let offset = (weekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -offset, to: selectedDate)!
        return (0..<7).map { calendar.date(byAdding: .day, value: $0, to: monday)! }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                header
                weekStrip
                LazyVStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(isToday ? "Leave a mark today." : "A page in your progress.")
                                .font(DayInInkTheme.handwriting(25, relativeTo: .title2))
                            Text("\(completed) of \(eligible.count) habits completed")
                                .font(.caption).foregroundStyle(DayInInkTheme.secondary)
                        }
                        Spacer()
                        Text("\(eligible.isEmpty ? 0 : Int(Double(completed) / Double(eligible.count) * 100))%")
                            .font(.subheadline.bold())
                            .foregroundStyle(DayInInkTheme.accent)
                            .monospacedDigit().padding(10).background(DayInInkTheme.paper, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .padding(.top, 8).padding(.bottom, 4)

                    if visible.isEmpty {
                        EmptyHabits(
                            title: emptyTitle,
                            message: emptyMessage,
                            actionTitle: store.activeHabits.isEmpty ? "Add your first habit" : nil,
                            action: addHabit
                        )
                    }
                    ForEach(visible) { habit in
                        HabitCard(habit: habit, date: selectedDate,
                                  edit: { logRequest = LogRequest(habit: habit, date: selectedDate) })
                    }

                    HStack(spacing: 10) {
                        Image(systemName: "sun.horizon").font(.title2).foregroundStyle(DayInInkTheme.accent)
                        Text(completed == eligible.count && !eligible.isEmpty
                             ? "You showed up. That’s a day well spent."
                             : "Progress grows from showing up.")
                            .font(DayInInkTheme.handwriting(18, relativeTo: .subheadline)).foregroundStyle(DayInInkTheme.secondary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
                }
                .padding(.horizontal, 20).padding(.bottom, 14)
            }
        }
        .scrollIndicators(.hidden)
        .sensoryFeedback(.success, trigger: completed)
        .sheet(item: $logRequest) { request in LogEntryView(habit: request.habit, day: request.day) }
        .sheet(isPresented: $showCalendar) {
            NavigationStack {
                DatePicker("Review a day", selection: Binding(get: { selectedDate }, set: { selectedDate = $0 }),
                           in: ...calendar.startOfDay(for: Date()), displayedComponents: .date)
                    .datePickerStyle(.graphical).padding()
                    .navigationTitle("Your calendar").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showCalendar = false } } }
            }
            .presentationDetents([.medium, .large])
        }
        .onChange(of: calendar) { _, _ in refreshToday() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { refreshToday() } }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in refreshToday() }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name.NSSystemTimeZoneDidChange)) { _ in refreshToday() }
    }

    private var header: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
            : AnyLayout(HStackLayout(alignment: .center))
        return layout {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Image(systemName: "sun.horizon.fill")
                    Text("DAY IN INK").tracking(3)
                }
                .font(.caption2.bold())
                .foregroundStyle(DayInInkTheme.accent)
                Button { showCalendar = true } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(isToday ? "Today" : habitDateLabel(selectedDate, format: .dateTime.month(.abbreviated).day()))
                            .font(DayInInkTheme.handwriting(36, relativeTo: .largeTitle))
                        Image(systemName: "chevron.down").font(.caption.weight(.semibold))
                    }.foregroundStyle(DayInInkTheme.ink)
                }
                .accessibilityLabel("Choose date, \(habitDateLabel(selectedDate, format: Date.FormatStyle(date: .complete, time: .omitted)))")
                Text(habitDateLabel(selectedDate, format: .dateTime.weekday(.wide).month(.wide).day()))
                    .font(.caption).foregroundStyle(DayInInkTheme.secondary)
            }
            Spacer(minLength: 8)
            Menu {
                Picker("Show habits", selection: $filter) {
                    ForEach(HabitFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "line.3.horizontal.decrease")
                    Text(filter.rawValue)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(DayInInkTheme.accent)
                .padding(12)
                .background(DayInInkTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityLabel("Filter habits: \(filter.rawValue)")
        }
        .padding(.horizontal, 24).padding(.top, 16).padding(.bottom, 20)
    }

    private var weekStrip: some View {
        VStack(spacing: 10) {
            HStack {
                Button { moveWeek(-1) } label: {
                    Image(systemName: "chevron.left").frame(minWidth: 44, minHeight: 44)
                }.accessibilityLabel("Previous week")
                Spacer()
                if !isToday {
                    Button("Back to today") { selectedDate = calendar.startOfDay(for: Date()) }
                        .font(.caption.weight(.medium))
                } else {
                    Text("THIS WEEK").font(.caption2.weight(.semibold))
                        .tracking(2).foregroundStyle(DayInInkTheme.secondary)
                }
                Spacer()
                Button { moveWeek(1) } label: {
                    Image(systemName: "chevron.right").frame(minWidth: 44, minHeight: 44)
                }
                .disabled(week.last! >= calendar.startOfDay(for: Date()))
                .accessibilityLabel("Next week")
            }
            .font(.caption.weight(.semibold)).foregroundStyle(DayInInkTheme.secondary)

            let columns = dynamicTypeSize.isAccessibilitySize ? 3 : 7
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: columns), spacing: 4) {
                ForEach(week, id: \.self) { date in
                    let selected = calendar.isDate(date, inSameDayAs: selectedDate)
                    let dayHabits = store.activeHabits.filter { $0.startDay <= HabitDay(date, calendar: calendar) }
                    let done = dayHabits.filter { store.archive.isComplete($0, on: date) }.count
                    Button { selectedDate = date } label: {
                        VStack(spacing: 12) {
                            Text(habitDateLabel(date, format: .dateTime.weekday(.narrow)))
                                .font(.caption.weight(selected ? .semibold : .regular))
                                .foregroundStyle(selected ? .white : DayInInkTheme.secondary)
                            Text(habitDateLabel(date, format: .dateTime.day()))
                                .font(.system(.body, design: .serif).weight(selected ? .bold : .medium))
                                .foregroundStyle(selected ? .white : DayInInkTheme.ink)
                            Capsule()
                                .fill(selected ? .white.opacity(0.25) : DayInInkTheme.accent.opacity(0.12))
                                .frame(width: 24, height: 3)
                                .overlay(alignment: .leading) {
                                    Capsule().fill(selected ? .white : DayInInkTheme.accent)
                                        .frame(width: 24 * (dayHabits.isEmpty ? 0 : Double(done) / Double(dayHabits.count)), height: 3)
                                }
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(selected ? DayInInkTheme.accent : .clear, in: RoundedRectangle(cornerRadius: 12))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(date > calendar.startOfDay(for: Date()))
                    .opacity(date > calendar.startOfDay(for: Date()) ? 0.35 : 1)
                    .accessibilityLabel("\(habitDateLabel(date, format: Date.FormatStyle(date: .complete, time: .omitted))), \(done) completed")
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }
        .padding(.horizontal, 20).padding(.bottom, 12)
    }

    private func moveWeek(_ offset: Int) {
        selectedDate = min(calendar.date(byAdding: .day, value: offset * 7, to: selectedDate)!, calendar.startOfDay(for: Date()))
    }

    private func refreshToday() {
        let today = HabitDay(Date(), calendar: calendar)
        if selectedDay == lastToday || selectedDay > today || selectedDay.date(calendar: calendar) == nil { selectedDay = today }
        lastToday = today
    }

    private var emptyTitle: String {
        if store.activeHabits.isEmpty { return "Make room for a good habit" }
        if eligible.isEmpty { return "A fresh start is ahead" }
        return filter == .completed ? "Your first win is waiting" : "All caught up!"
    }

    private var emptyMessage: String {
        if store.activeHabits.isEmpty { return "Start small. Give one thing a little attention each day." }
        if eligible.isEmpty { return "Your habits hadn’t started on this date. Choose a more recent day." }
        return filter == .completed ? "Completed habits will appear here." : "You’ve completed every habit for this day."
    }
}

struct LogRequest: Identifiable {
    let id = UUID()
    let habit: Habit
    let day: HabitDay

    init(habit: Habit, date: Date) {
        self.habit = habit
        self.day = HabitDay(date)
    }
}

struct HabitCard: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var errorMessage: String?
    let habit: Habit
    let date: Date
    let edit: () -> Void

    private var entry: HabitEntry? { store.entry(habit, on: date) }
    private var kind: HabitKind { entry?.kind ?? habit.kind }
    private var complete: Bool { entry?.isComplete ?? false }
    private var streak: Int { store.archive.streak(for: habit, through: date) }

    var body: some View {
        VStack(spacing: 0) {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                : AnyLayout(HStackLayout(spacing: 12))
            layout {
                NavigationLink(value: habit) {
                    HStack(spacing: 12) {
                        HabitIcon(habit: habit)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(habit.name)
                                .font(DayInInkTheme.handwriting(21, relativeTo: .headline))
                                .foregroundStyle(DayInInkTheme.ink)
                                .multilineTextAlignment(.leading)
                                .lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                            Text(status)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(DayInInkTheme.secondary)
                                .lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                                .accessibilityLabel(kind == .progress
                                    ? "\(spokenAmount(entry?.value ?? 0)) of \(spokenAmount(entry?.target ?? habit.target)) \(entry?.unit ?? habit.unit)"
                                    : status)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("habit-\(habit.name)")

                VStack(alignment: .trailing, spacing: 6) {
                    if streak > 0 {
                        Label("\(streak) \(streak == 1 ? "day" : "days")", systemImage: "sparkle")
                            .font(.caption2.weight(.medium)).foregroundStyle(DayInInkTheme.secondary)
                    }
                    Button { mutate { try await store.quickLog(habit, on: date) } } label: {
                        Image(systemName: complete ? "checkmark" : (entry?.checkIn == .failed ? "xmark" : "plus"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DayInInkTheme.accent)
                            .frame(width: 30, height: 30)
                            .background(DayInInkTheme.accent.opacity(complete ? 0.06 : 0), in: RoundedRectangle(cornerRadius: 5))
                            .overlay(RoundedRectangle(cornerRadius: 5).stroke(DayInInkTheme.accent.opacity(0.65), lineWidth: 1))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("quick-\(habit.name)")
                    .accessibilityLabel(kind == .checkIn
                                        ? "\(complete ? "Mark failed" : "Mark passed") for \(habit.name)"
                                        : "Add \(spokenAmount(habit.step)) \(entry?.unit ?? habit.unit) to \(habit.name)")
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 16)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    DayInInkTheme.rule.opacity(0.6)
                    DayInInkTheme.accent.frame(width: geometry.size.width * (entry?.fraction ?? 0))
                }
            }.frame(height: 3).padding(.horizontal, 16).padding(.bottom, 14)
        }
        .paperCard()
        .overlay(alignment: .leading) {
            Rectangle().fill(habit.color.tint.opacity(0.65)).frame(width: 2)
                .padding(.vertical, 14)
        }
        .contextMenu {
            Button("Edit this day", systemImage: "pencil", action: edit)
            if kind == .checkIn {
                Button("Mark passed", systemImage: "checkmark") { mutate { try await store.record(habit, on: date, checkIn: .passed) } }
                Button("Mark failed", systemImage: "xmark") { mutate { try await store.record(habit, on: date, checkIn: .failed) } }
            }
            if entry != nil {
                Button("Clear this day", systemImage: "arrow.uturn.backward") { mutate { try await store.clear(habit, on: date) } }
            }
        }
        .accessibilityAction(named: "Edit this day", edit)
        .mutationError($errorMessage)
    }

    private func mutate(_ operation: @escaping @MainActor () async throws -> Void) {
        Task {
            do { try await operation() }
            catch { errorMessage = error.localizedDescription }
        }
    }

    private var status: String {
        if kind == .checkIn {
            switch entry?.checkIn {
            case .passed: "Passed ✓"
            case .failed:
                store.archive.entry(for: habit, on: date) == nil
                    ? "Not yet · mark passed when done" : "Failed · try again tomorrow"
            case nil: "Daily check-in"
            }
        } else {
            "\(amount(entry?.value ?? 0)) / \(amount(entry?.target ?? habit.target)) \(entry?.unit ?? habit.unit)"
        }
    }
}
