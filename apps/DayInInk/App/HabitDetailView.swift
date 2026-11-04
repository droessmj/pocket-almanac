import SwiftUI
import UIKit
import HabitKit

struct HabitDetailView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.calendar) private var calendar
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let habitID: UUID
    @State private var days = 30
    @State private var editing = false
    @State private var confirmDelete = false
    @State private var logRequest: LogRequest?
    @State private var showHistory = false
    @State private var historyDay = HabitDay(Date())
    @State private var errorMessage: String?
    @State private var saving = false
    @State private var today = HabitDay(Date())

    private var historyDate: Date {
        get { historyDay.date(calendar: calendar) ?? calendar.startOfDay(for: Date()) }
        nonmutating set { historyDay = HabitDay(newValue, calendar: calendar) }
    }

    private var habit: Habit? { store.archive.habits.first { $0.id == habitID } }

    var body: some View {
        Group {
            if let habit { content(habit) }
        }
        .background(DayInInkTheme.background)
        .navigationTitle("Your progress").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit habit", systemImage: "pencil") { editing = true }
                    if let habit {
                        Button(habit.isArchived ? "Restore habit" : "Archive habit", systemImage: "archivebox") {
                            mutate { try await store.archiveHabit(habit) }
                        }.disabled(saving)
                        Button("Delete habit", systemImage: "trash", role: .destructive) { confirmDelete = true }
                    }
                } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }
                .accessibilityLabel("Habit options")
            }
        }
        .sheet(isPresented: $editing) { if let habit { HabitEditor(habit: habit) } }
        .sheet(item: $logRequest) { request in LogEntryView(habit: request.habit, day: request.day) }
        .sheet(isPresented: $showHistory, onDismiss: {
            // Present after the date picker is dismissed so the sheets don't compete.
            if let habit, historySelected { logRequest = LogRequest(habit: habit, date: historyDate) }
            historySelected = false
        }) {
            if let habit {
                let now = Date()
                let historyRange = habit.historyDateRange(through: now, calendar: calendar)
                NavigationStack {
                    Group {
                        if let historyRange {
                            DatePicker("Choose a day", selection: Binding(get: { historyDate }, set: { historyDate = $0 }),
                                       in: historyRange, displayedComponents: .date)
                                .datePickerStyle(.graphical).padding()
                        } else {
                            ContentUnavailableView("This habit starts in the future",
                                                   systemImage: "calendar",
                                                   description: Text("History will be available on its start date. Check your iPhone’s date and time if this is unexpected."))
                        }
                    }
                        .navigationTitle("Review a day").navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showHistory = false } }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Check in") { historySelected = true; showHistory = false }
                                    .disabled(historyRange == nil)
                            }
                        }
                }.presentationDetents([.medium, .large])
            }
        }
        .confirmationDialog("Permanently delete this habit and all its check-ins?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete habit", role: .destructive) {
                if let habit {
                    mutate {
                        try await store.delete(habit)
                        dismiss()
                    }
                }
            }
        }
        .mutationError($errorMessage)
        .onChange(of: scenePhase) { _, phase in if phase == .active { today = HabitDay(Date(), calendar: calendar) } }
        .onChange(of: calendar) { _, _ in today = HabitDay(Date(), calendar: calendar) }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            today = HabitDay(Date(), calendar: calendar)
        }
    }

    @State private var historySelected = false

    private func mutate(_ operation: @escaping @MainActor () async throws -> Void) {
        guard !saving else { return }
        saving = true
        Task {
            defer { saving = false }
            do { try await operation() }
            catch { errorMessage = error.localizedDescription }
        }
    }

    private func content(_ habit: Habit) -> some View {
        let samples = store.archive.samples(for: habit, days: days, calendar: calendar)
        let history = Array(samples.reversed().prefix(14))
        let canLogToday = habit.startDay <= today
        let completed = samples.filter { $0.entry?.isComplete == true }.count
        let logged = samples.filter { $0.entry != nil && !$0.isDefault }.count
        let failed = samples.filter { $0.entry?.checkIn == .failed }.count
        let hasProgress = habit.kind == .progress || samples.contains { $0.entry?.kind == .progress }

        return ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                let headerLayout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 16))
                    : AnyLayout(HStackLayout(spacing: 16))
                headerLayout {
                    HabitIcon(habit: habit, size: 68)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(habit.name).font(DayInInkTheme.handwriting(27, relativeTo: .title2))
                        Text(habit.kind == .checkIn ? "One promise, every day" : "Daily goal · \(amount(habit.target)) \(habit.unit)")
                            .font(.subheadline).foregroundStyle(DayInInkTheme.secondary)
                        if habit.isArchived {
                            Text("Archived · history kept").font(.caption).foregroundStyle(habit.color.textColor)
                        }
                    }
                }.padding(.top, 18)

                Button { logRequest = LogRequest(habit: habit, date: calendar.startOfDay(for: Date())) } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Check in for today").fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "arrow.right").font(.caption.bold())
                    }
                    .foregroundStyle(.white).padding(18)
                    .background(DayInInkTheme.accent, in: RoundedRectangle(cornerRadius: 8))
                }
                .disabled(!canLogToday)
                .opacity(canLogToday ? 1 : 0.6)
                if !canLogToday {
                    Text("This habit starts on \(habit.startDate(calendar: calendar).map { habitDateLabel($0, format: Date.FormatStyle(date: .abbreviated, time: .omitted)) } ?? "a future day"). Today’s check-in will be available on its start day. Check your iPhone’s date and time if this is unexpected.")
                        .font(.caption).foregroundStyle(DayInInkTheme.secondary)
                        .accessibilityIdentifier("future-start-explanation")
                }

                periodPicker(days: $days)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading),
                                         count: dynamicTypeSize.isAccessibilitySize ? 1 : 3), spacing: 12) {
                    metric("\(completionPercent(samples))%", label: "Completion", color: habit.color.textColor)
                    metric("\(store.archive.streak(for: habit, calendar: calendar))", label: "Current streak", color: habit.color.textColor)
                    metric("\(logged)", label: "Days logged", color: habit.color.textColor)
                }

                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your daily rhythm").font(DayInInkTheme.handwriting(23, relativeTo: .headline))
                        Text("\(completed) \(completed == 1 ? "win" : "wins")").font(.caption.weight(.medium)).foregroundStyle(habit.color.textColor)
                    }
                    TrendChart(samples: samples, color: habit.color.tint).frame(height: 185)
                    VStack(alignment: .leading, spacing: 5) {
                        Label(hasProgress ? "% of that day’s goal · × = fail" : "Pass = 100% · × = fail", systemImage: "circle.fill")
                            .font(.caption).foregroundStyle(DayInInkTheme.secondary)
                        Text(habit.kind == .checkIn
                             ? (habit.defaultPassed ? "Passed unless marked failed" : "Failed unless marked passed")
                             : "Gaps = unrecorded").font(.caption).foregroundStyle(DayInInkTheme.secondary)
                    }
                }.dayininkCard()

                VStack(alignment: .leading, spacing: 14) {
                    Text("Showing up matters").font(DayInInkTheme.handwriting(23, relativeTo: .headline))
                    Text(habit.kind == .checkIn
                         ? "\(completed) passed · \(failed) failed · \(samples.filter(\.isDefault).count) \(habit.defaultPassed ? "passed" : "failed") by default"
                         : "\(completed) completed · \(failed) failed · \(samples.filter { $0.entry == nil }.count) unrecorded")
                        .font(.caption).foregroundStyle(DayInInkTheme.secondary)
                    Text("Based on \(samples.count) \(samples.count == 1 ? "day" : "days") since \(habitDateLabel(samples.first?.date ?? habit.startDate(calendar: calendar) ?? Date(), format: Date.FormatStyle(date: .abbreviated, time: .omitted))). Today is included and can still be in progress.")
                        .font(.caption).foregroundStyle(DayInInkTheme.secondary)
                }.dayininkCard()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Daily history").font(DayInInkTheme.handwriting(25, relativeTo: .title3))
                    Button("Choose date") { historyDate = calendar.startOfDay(for: Date()); showHistory = true }.font(.caption.weight(.medium))
                }
                VStack(spacing: 0) {
                    ForEach(history) { sample in
                        Button { logRequest = LogRequest(habit: habit, date: sample.date) } label: {
                            let rowLayout = dynamicTypeSize.isAccessibilitySize
                                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                                : AnyLayout(HStackLayout(spacing: 12))
                            rowLayout {
                                ZStack {
                                    Circle().fill(historyColor(sample, habit: habit).opacity(0.1)).frame(width: 30, height: 30)
                                    Image(systemName: historyIcon(sample)).font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(historyColor(sample, habit: habit))
                                }
                                Text(calendar.isDateInToday(sample.date) ? "Today" : habitDateLabel(sample.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                                    .font(.subheadline).foregroundStyle(DayInInkTheme.ink)
                                Spacer()
                                Text(historyLabel(sample)).font(.caption).foregroundStyle(DayInInkTheme.secondary)
                                Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold)).foregroundStyle(DayInInkTheme.secondary)
                            }.padding(.vertical, 12).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        if sample.id != history.last?.id { Divider().opacity(0.4) }
                    }
                }
                .padding(.horizontal, 16).paperCard()
                Text("Tap a day to update it. Choose any earlier date to review older check-ins.")
                    .font(.caption).foregroundStyle(DayInInkTheme.secondary)
            }
            .padding(.horizontal, 22).padding(.bottom, 30)
        }
    }

    private func metric(_ value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value).font(.system(.title2, design: .rounded).monospacedDigit()).foregroundStyle(color)
            Text(label).font(.caption.weight(.medium)).foregroundStyle(DayInInkTheme.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(14)
        .paperCard()
    }

    private func historyLabel(_ sample: HabitSample) -> String {
        guard let entry = sample.entry else { return "Unrecorded" }
        if entry.kind == .checkIn { return entry.checkIn == .passed ? "Passed" : "Failed" }
        return "\(amount(entry.value)) / \(amount(entry.target)) \(entry.unit)"
    }

    private func historyIcon(_ sample: HabitSample) -> String {
        guard let entry = sample.entry else { return "minus" }
        if entry.isComplete { return "checkmark" }
        return entry.checkIn == .failed ? "xmark" : "ellipsis"
    }

    private func historyColor(_ sample: HabitSample, habit: Habit) -> Color {
        sample.entry == nil || sample.entry?.checkIn == .failed ? DayInInkTheme.secondary : habit.color.tint
    }
}
