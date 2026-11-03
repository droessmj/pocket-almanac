import SwiftUI
import HabitKit
import UIKit

private enum HabitFilter: String, CaseIterable {
    case all = "All", remaining = "Remaining", completed = "Completed"
}

struct TodayView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var lastToday = Calendar.current.startOfDay(for: Date())
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var filter = HabitFilter.all
    @State private var showCalendar = false
    @State private var logRequest: LogRequest?
    let addHabit: () -> Void

    private let calendar = Calendar.current
    private var isToday: Bool { calendar.isDateInToday(selectedDate) }
    private var eligible: [Habit] {
        store.activeHabits.filter { calendar.startOfDay(for: $0.createdAt) <= selectedDate }
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
        VStack(spacing: 0) {
            header
            weekStrip
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(isToday ? "Leave a mark today." : "A page in your progress.")
                                .font(DayInInkTheme.handwriting(25, relativeTo: .title2))
                            Text("\(completed) of \(eligible.count) habits completed")
                                .font(.caption).foregroundStyle(DayInInkTheme.secondary)
                        }
                        Spacer()
                        Text("\(eligible.isEmpty ? 0 : Int(Double(completed) / Double(eligible.count) * 100))%")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(DayInInkTheme.accent)
                            .monospacedDigit().padding(10).background(DayInInkTheme.paper, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .padding(.top, 24).padding(.bottom, 4)

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
            .scrollIndicators(.hidden)
        }
        .sensoryFeedback(.success, trigger: completed)
        .sheet(item: $logRequest) { request in LogEntryView(habit: request.habit, date: request.date) }
        .sheet(isPresented: $showCalendar) {
            NavigationStack {
                DatePicker("Review a day", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.graphical).padding()
                    .navigationTitle("Your calendar").navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showCalendar = false } } }
            }
            .presentationDetents([.medium, .large])
        }
        .onChange(of: selectedDate) { _, date in selectedDate = calendar.startOfDay(for: date) }
        .onChange(of: scenePhase) { _, phase in if phase == .active { refreshToday() } }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in refreshToday() }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Image(systemName: "sun.horizon.fill")
                    Text("DAY IN INK").tracking(3)
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(DayInInkTheme.accent)
                Button { showCalendar = true } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(isToday ? "Today" : selectedDate.formatted(.dateTime.month(.abbreviated).day()))
                            .font(DayInInkTheme.handwriting(36, relativeTo: .largeTitle))
                        Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold))
                    }.foregroundStyle(DayInInkTheme.ink)
                }
                .accessibilityLabel("Choose date, \(selectedDate.formatted(date: .complete, time: .omitted))")
                Text(selectedDate.formatted(.dateTime.weekday(.wide).month(.wide).day()))
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
                    Image(systemName: "chevron.left").frame(width: 36, height: 28)
                }.accessibilityLabel("Previous week")
                Spacer()
                if !isToday {
                    Button("Back to today") { selectedDate = calendar.startOfDay(for: Date()) }
                        .font(.caption.weight(.medium))
                } else {
                    Text("THIS WEEK").font(.system(size: 9, weight: .semibold))
                        .tracking(2).foregroundStyle(DayInInkTheme.secondary)
                }
                Spacer()
                Button { moveWeek(1) } label: {
                    Image(systemName: "chevron.right").frame(width: 36, height: 28)
                }
                .disabled(week.last! >= calendar.startOfDay(for: Date()))
                .accessibilityLabel("Next week")
            }
            .font(.system(size: 12, weight: .semibold)).foregroundStyle(DayInInkTheme.secondary)

            HStack(spacing: 2) {
                ForEach(week, id: \.self) { date in
                    let selected = calendar.isDate(date, inSameDayAs: selectedDate)
                    let dayHabits = store.activeHabits.filter { calendar.startOfDay(for: $0.createdAt) <= date }
                    let done = dayHabits.filter { store.archive.isComplete($0, on: date) }.count
                    Button { selectedDate = date } label: {
                        VStack(spacing: 12) {
                            Text(date.formatted(.dateTime.weekday(.narrow)))
                                .font(.system(size: 12, weight: selected ? .semibold : .regular))
                                .foregroundStyle(selected ? .white.opacity(0.8) : DayInInkTheme.secondary)
                            Text(date.formatted(.dateTime.day()))
                                .font(.system(size: 17, weight: selected ? .bold : .medium, design: .serif))
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
                    .accessibilityLabel("\(date.formatted(date: .complete, time: .omitted)), \(done) completed")
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
        let today = calendar.startOfDay(for: Date())
        if calendar.isDate(selectedDate, inSameDayAs: lastToday) { selectedDate = today }
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
    let date: Date
}

struct HabitCard: View {
    @Environment(HabitStore.self) private var store
    let habit: Habit
    let date: Date
    let edit: () -> Void

    private var entry: HabitEntry? { store.entry(habit, on: date) }
    private var kind: HabitKind { entry?.kind ?? habit.kind }
    private var complete: Bool { entry?.isComplete ?? false }
    private var streak: Int { store.archive.streak(for: habit, through: date) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                NavigationLink(value: habit) {
                    HStack(spacing: 12) {
                        HabitIcon(habit: habit)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(habit.name)
                                .font(DayInInkTheme.handwriting(21, relativeTo: .headline))
                                .foregroundStyle(DayInInkTheme.ink)
                                .multilineTextAlignment(.leading)
                            Text(status)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(DayInInkTheme.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityIdentifier("habit-\(habit.name)")

                VStack(alignment: .trailing, spacing: 6) {
                    if streak > 0 {
                        Label("\(streak) \(streak == 1 ? "day" : "days")", systemImage: "sparkle")
                            .font(.system(size: 10, weight: .medium)).foregroundStyle(DayInInkTheme.secondary)
                    }
                    Button { withAnimation(.snappy) { store.quickLog(habit, on: date) } } label: {
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
                                        : "Add \(amount(habit.step)) \(entry?.unit ?? habit.unit) to \(habit.name)")
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
                Button("Mark passed", systemImage: "checkmark") { store.record(habit, on: date, checkIn: .passed) }
                Button("Mark failed", systemImage: "xmark") { store.record(habit, on: date, checkIn: .failed) }
            }
            if entry != nil {
                Button("Clear this day", systemImage: "arrow.uturn.backward") { store.clear(habit, on: date) }
            }
        }
        .accessibilityAction(named: "Edit this day", edit)
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
