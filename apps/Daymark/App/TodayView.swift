import SwiftUI
import HabitKit

private enum HabitFilter: String, CaseIterable {
    case all = "All", remaining = "Remaining", completed = "Completed"
}

struct TodayView: View {
    @Environment(HabitStore.self) private var store
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
        // Always use Monday first, as in the reference.
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
                            Text(isToday ? "A little better, every day." : "Every little step counts.")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                            Text("\(completed) of \(eligible.count) habits completed")
                                .font(.caption).foregroundStyle(DaymarkTheme.secondary)
                        }
                        Spacer()
                        Text("\(eligible.isEmpty ? 0 : Int(Double(completed) / Double(eligible.count) * 100))%")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(DaymarkTheme.accent)
                            .padding(10).background(.white, in: Capsule())
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
                        Text("🌱").font(.title2)
                        Text(completed == eligible.count && !eligible.isEmpty
                             ? "You showed up. That’s a day well spent."
                             : "Progress grows from showing up.")
                            .font(.caption).foregroundStyle(DaymarkTheme.secondary)
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
    }

    private var header: some View {
        HStack {
            Menu {
                Picker("Show habits", selection: $filter) {
                    ForEach(HabitFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(filter.rawValue).font(.subheadline.weight(.medium))
                    Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(.white).padding(.horizontal, 14).padding(.vertical, 10)
                .background(DaymarkTheme.accent.gradient, in: Capsule())
            }
            .accessibilityLabel("Filter habits: \(filter.rawValue)")
            Spacer(minLength: 8)
            Button { showCalendar = true } label: {
                VStack(spacing: 3) {
                    Text(isToday ? "Today" : selectedDate.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(DaymarkTheme.ink)
                    Text(selectedDate.formatted(.dateTime.month(.wide).year()))
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(DaymarkTheme.secondary)
                }
            }
            .accessibilityLabel("Choose date, \(selectedDate.formatted(date: .complete, time: .omitted))")
            Spacer(minLength: 8)
            ZStack {
                ProgressRing(fraction: eligible.isEmpty ? 0 : Double(completed) / Double(eligible.count), lineWidth: 2)
                Text(completed == eligible.count && !eligible.isEmpty ? "🥳" : "🙂").font(.system(size: 26))
            }
            .frame(width: 42, height: 42)
            .accessibilityLabel("\(completed) of \(eligible.count) habits completed")
        }
        .padding(.horizontal, 24).padding(.top, 10).padding(.bottom, 22)
        .background(.white)
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
                    Text("YOUR DAILY RHYTHM").font(.system(size: 9, weight: .semibold))
                        .tracking(2).foregroundStyle(DaymarkTheme.secondary)
                }
                Spacer()
                Button { moveWeek(1) } label: {
                    Image(systemName: "chevron.right").frame(width: 36, height: 28)
                }
                .disabled(week.last! >= calendar.startOfDay(for: Date()))
                .accessibilityLabel("Next week")
            }
            .font(.system(size: 12, weight: .semibold)).foregroundStyle(DaymarkTheme.secondary)

            HStack(spacing: 2) {
                ForEach(week, id: \.self) { date in
                    let selected = calendar.isDate(date, inSameDayAs: selectedDate)
                    let dayHabits = store.activeHabits.filter { calendar.startOfDay(for: $0.createdAt) <= date }
                    let done = dayHabits.filter { store.archive.isComplete($0, on: date) }.count
                    Button { selectedDate = date } label: {
                        VStack(spacing: 12) {
                            Text(date.formatted(.dateTime.weekday(.narrow)))
                                .font(.system(size: 12, weight: selected ? .semibold : .regular))
                                .foregroundStyle(selected ? DaymarkTheme.ink : DaymarkTheme.secondary)
                            ZStack {
                                ProgressRing(fraction: dayHabits.isEmpty ? 0 : Double(done) / Double(dayHabits.count), lineWidth: 2.5)
                                Text(date.formatted(.dateTime.day()))
                                    .font(.system(size: 15, weight: selected ? .bold : .regular, design: .rounded))
                                    .foregroundStyle(selected ? DaymarkTheme.ink : DaymarkTheme.secondary)
                            }.frame(width: 34, height: 34)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(selected ? DaymarkTheme.accent.opacity(0.045) : .clear, in: Capsule())
                        .overlay(Capsule().stroke(selected ? DaymarkTheme.accent.opacity(0.2) : .clear, lineWidth: 1))
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
        .padding(.horizontal, 18).padding(.bottom, 12).background(.white)
    }

    private func moveWeek(_ offset: Int) {
        selectedDate = min(calendar.date(byAdding: .day, value: offset * 7, to: selectedDate)!, calendar.startOfDay(for: Date()))
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
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundStyle(DaymarkTheme.ink)
                                .multilineTextAlignment(.leading)
                            Text(status)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(habit.color.tint)
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(habit.color.tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 5))
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }.buttonStyle(.plain)

                VStack(alignment: .trailing, spacing: 6) {
                    if streak > 0 {
                        Text("🔥 \(streak) \(streak == 1 ? "day" : "days")")
                            .font(.system(size: 10, weight: .medium)).foregroundStyle(DaymarkTheme.secondary)
                    }
                    Button { withAnimation(.snappy) { store.quickLog(habit, on: date) } } label: {
                        Image(systemName: complete ? "checkmark" : (entry?.checkIn == .failed ? "xmark" : "plus"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(complete ? .white : habit.color.tint)
                            .frame(width: 30, height: 30)
                            .background(complete ? habit.color.tint : .clear, in: Circle())
                            .overlay(Circle().stroke(habit.color.tint.opacity(0.7), lineWidth: 1.3))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(habit.kind == .checkIn
                                        ? "\(complete ? "Undo pass" : "Mark passed") for \(habit.name)"
                                        : "Add \(amount(habit.step)) \(habit.unit) to \(habit.name)")
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 16)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    habit.color.tint.opacity(0.15)
                    habit.color.tint.frame(width: geometry.size.width * (entry?.fraction ?? 0))
                }
            }.frame(height: 5)
        }
        .background(.white, in: RoundedRectangle(cornerRadius: 22))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .contextMenu {
            Button("Edit this day", systemImage: "pencil", action: edit)
            if habit.kind == .checkIn {
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
        if habit.kind == .checkIn {
            switch entry?.checkIn {
            case .passed: "Passed ✓"
            case .failed: "Failed · try again tomorrow"
            case nil: "Daily check-in"
            }
        } else {
            "\(amount(entry?.value ?? 0)) / \(amount(entry?.target ?? habit.target)) \(entry?.unit ?? habit.unit)"
        }
    }
}
