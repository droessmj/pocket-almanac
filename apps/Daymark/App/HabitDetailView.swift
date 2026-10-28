import SwiftUI
import HabitKit

struct HabitDetailView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let habitID: UUID
    @State private var days = 30
    @State private var editing = false
    @State private var confirmDelete = false
    @State private var logRequest: LogRequest?
    @State private var showHistory = false
    @State private var historyDate = Date()

    private var habit: Habit? { store.archive.habits.first { $0.id == habitID } }

    var body: some View {
        Group {
            if let habit { content(habit) }
        }
        .background(DaymarkTheme.background)
        .navigationTitle("Your progress").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit habit", systemImage: "pencil") { editing = true }
                    if let habit {
                        Button(habit.isArchived ? "Restore habit" : "Archive habit", systemImage: "archivebox") { store.archiveHabit(habit) }
                        Button("Delete habit", systemImage: "trash", role: .destructive) { confirmDelete = true }
                    }
                } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }
                .accessibilityLabel("Habit options")
            }
        }
        .sheet(isPresented: $editing) { if let habit { HabitEditor(habit: habit) } }
        .sheet(item: $logRequest) { request in LogEntryView(habit: request.habit, date: request.date) }
        .sheet(isPresented: $showHistory, onDismiss: {
            // Present after the date picker is dismissed so the sheets don't compete.
            if let habit, historySelected { logRequest = LogRequest(habit: habit, date: historyDate) }
            historySelected = false
        }) {
            if let habit {
                NavigationStack {
                    DatePicker("Choose a day", selection: $historyDate,
                               in: Calendar.current.startOfDay(for: habit.createdAt)...Date(), displayedComponents: .date)
                        .datePickerStyle(.graphical).padding()
                        .navigationTitle("Review a day").navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showHistory = false } }
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Check in") { historySelected = true; showHistory = false }
                            }
                        }
                }.presentationDetents([.medium, .large])
            }
        }
        .confirmationDialog("Permanently delete this habit and all its check-ins?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete habit", role: .destructive) {
                if let habit, store.delete(habit) { dismiss() }
            }
        }
    }

    @State private var historySelected = false

    private func content(_ habit: Habit) -> some View {
        let samples = store.archive.samples(for: habit, days: days)
        let completed = samples.filter { $0.entry?.isComplete == true }.count
        let logged = samples.filter { $0.entry != nil && !$0.isDefault }.count
        let failed = samples.filter { $0.entry?.checkIn == .failed }.count

        return ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 16) {
                    HabitIcon(habit: habit, size: 68)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(habit.name).font(DaymarkTheme.handwriting(27, relativeTo: .title2))
                        Text(habit.kind == .checkIn ? "One promise, every day" : "Daily goal · \(amount(habit.target)) \(habit.unit)")
                            .font(.subheadline).foregroundStyle(DaymarkTheme.secondary)
                        if habit.isArchived {
                            Text("Archived · history kept").font(.caption).foregroundStyle(habit.color.tint)
                        }
                    }
                }.padding(.top, 18)

                Button { logRequest = LogRequest(habit: habit, date: Date()) } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Check in for today").fontWeight(.semibold)
                        Spacer()
                        Image(systemName: "arrow.right").font(.caption.bold())
                    }
                    .foregroundStyle(.white).padding(18)
                    .background(DaymarkTheme.accent, in: RoundedRectangle(cornerRadius: 8))
                }

                periodPicker(days: $days)

                HStack(spacing: 12) {
                    metric("\(completionPercent(samples))%", label: "Completion", color: habit.color.tint)
                    metric("\(store.archive.streak(for: habit))", label: "Current streak", color: habit.color.tint)
                    metric("\(logged)", label: "Days logged", color: habit.color.tint)
                }

                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("Your daily rhythm").font(DaymarkTheme.handwriting(23, relativeTo: .headline))
                        Spacer()
                        Text("\(completed) \(completed == 1 ? "win" : "wins")").font(.caption.weight(.medium)).foregroundStyle(habit.color.tint)
                    }
                    TrendChart(samples: samples, color: habit.color.tint).frame(height: 185)
                    HStack(spacing: 5) {
                        Circle().fill(habit.color.tint).frame(width: 6, height: 6)
                        Text(habit.kind == .progress ? "% of that day’s goal" : "Pass = 100%  ·  × = fail")
                            .font(.system(size: 10)).foregroundStyle(DaymarkTheme.secondary)
                        Spacer()
                        Text(habit.kind == .checkIn ? "Passed unless marked failed" : "Gaps = unrecorded").font(.system(size: 10)).foregroundStyle(DaymarkTheme.secondary)
                    }
                }.daymarkCard()

                VStack(alignment: .leading, spacing: 14) {
                    Text("Showing up matters").font(DaymarkTheme.handwriting(23, relativeTo: .headline))
                    Text(habit.kind == .checkIn
                         ? "\(completed) passed · \(failed) failed · \(samples.filter(\.isDefault).count) passed by default"
                         : "\(completed) completed · \(failed) failed · \(samples.count - logged) unrecorded")
                        .font(.caption).foregroundStyle(DaymarkTheme.secondary)
                    Text("Based on \(samples.count) \(samples.count == 1 ? "day" : "days") since \(max(habit.createdAt, samples.first?.date ?? habit.createdAt).formatted(date: .abbreviated, time: .omitted)). Today is included and can still be in progress.")
                        .font(.caption).foregroundStyle(DaymarkTheme.secondary)
                }.daymarkCard()

                HStack {
                    Text("Daily history").font(DaymarkTheme.handwriting(25, relativeTo: .title3))
                    Spacer()
                    Button("Choose date") { historyDate = Date(); showHistory = true }.font(.caption.weight(.medium))
                }
                VStack(spacing: 0) {
                    ForEach(Array(samples.reversed().prefix(14))) { sample in
                        Button { logRequest = LogRequest(habit: habit, date: sample.date) } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle().fill(historyColor(sample, habit: habit).opacity(0.1)).frame(width: 30, height: 30)
                                    Image(systemName: historyIcon(sample)).font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(historyColor(sample, habit: habit))
                                }
                                Text(Calendar.current.isDateInToday(sample.date) ? "Today" : sample.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                                    .font(.subheadline).foregroundStyle(DaymarkTheme.ink)
                                Spacer()
                                Text(historyLabel(sample)).font(.caption).foregroundStyle(DaymarkTheme.secondary)
                                Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold)).foregroundStyle(DaymarkTheme.secondary)
                            }.padding(.vertical, 12).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        if sample.date != samples.reversed().prefix(14).last?.date { Divider().opacity(0.4) }
                    }
                }
                .padding(.horizontal, 16).paperCard()
                Text("Tap a day to update it. Choose any earlier date to review older check-ins.")
                    .font(.caption).foregroundStyle(DaymarkTheme.secondary)
            }
            .padding(.horizontal, 22).padding(.bottom, 30)
        }
    }

    private func metric(_ value: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value).font(.system(.title2, design: .rounded).monospacedDigit()).foregroundStyle(color)
            Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(DaymarkTheme.secondary)
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
        sample.entry == nil || sample.entry?.checkIn == .failed ? DaymarkTheme.secondary : habit.color.tint
    }
}
