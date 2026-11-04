import SwiftUI
import UIKit
import Charts
import HabitKit

struct TrendsView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.calendar) private var calendar
    @State private var through = Date()
    @State private var days = 30

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Little steps add up.").font(DayInInkTheme.handwriting(31, relativeTo: .title))
                    Text("Your progress, one habit at a time.").font(DayInInkTheme.handwriting(18, relativeTo: .subheadline)).foregroundStyle(DayInInkTheme.secondary)
                }.padding(.top, 18)
                periodPicker(days: $days)
                if store.activeHabits.isEmpty {
                    EmptyHabits(title: "Your story starts here", message: "Add a habit, then check in to see your progress grow.")
                }
                ForEach(store.activeHabits) { habit in
                    TrendSummary(habit: habit, days: days, through: through)
                }
                Text("Trends include today and start on each habit’s saved start day. Unrecorded pass/fail days use the daily default you choose for each habit. Numeric habits need recorded progress.")
                    .font(.caption).foregroundStyle(DayInInkTheme.secondary).padding(.bottom, 8)
            }.padding(.horizontal, 22).padding(.bottom, 18)
        }
        .onChange(of: scenePhase) { _, phase in if phase == .active { through = Date() } }
        .onChange(of: calendar) { _, _ in through = Date() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in through = Date() }
    }
}

/// Sample and chart work happens only when this lazy row's body is requested.
private struct TrendSummary: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.calendar) private var calendar
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let habit: Habit
    let days: Int
    let through: Date

    var body: some View {
        let samples = store.archive.samples(for: habit, days: days, through: through, calendar: calendar)
        let completed = samples.filter { $0.entry?.isComplete == true }.count
        return NavigationLink(value: habit) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    HabitIcon(habit: habit, size: 42)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(habit.name).font(DayInInkTheme.handwriting(21, relativeTo: .headline))
                            .foregroundStyle(DayInInkTheme.ink)
                            .lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                        Text(samples.isEmpty ? "No days to review yet" : "\(completed) of \(samples.count) \(samples.count == 1 ? "day" : "days") completed")
                            .font(.caption).foregroundStyle(DayInInkTheme.secondary)
                            .lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                TrendChart(samples: samples, color: habit.color.tint, compact: true)
                    .frame(height: dynamicTypeSize.isAccessibilitySize ? 240 : 68)
                let layout = dynamicTypeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                    : AnyLayout(HStackLayout())
                layout {
                    Text("\(completionPercent(samples))% completion")
                        .font(.caption.weight(.semibold)).foregroundStyle(habit.color.textColor)
                    Spacer(minLength: 0)
                    Label("\(store.archive.streak(for: habit, through: through, calendar: calendar, now: through)) day streak", systemImage: "sparkle")
                        .font(.caption).foregroundStyle(DayInInkTheme.secondary)
                        .lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                }
            }.dayininkCard()
        }.buttonStyle(.plain)
    }
}

func completionPercent(_ samples: [HabitSample]) -> Int {
    guard !samples.isEmpty else { return 0 }
    return Int((Double(samples.filter { $0.entry?.isComplete == true }.count) / Double(samples.count) * 100).rounded())
}

func periodPicker(days: Binding<Int>) -> some View {
    Picker("Trend period", selection: days) {
        Text("7 days").tag(7)
        Text("30 days").tag(30)
        Text("90 days").tag(90)
    }.pickerStyle(.segmented)
}

struct TrendChart: View {
    @Environment(\.calendar) private var calendar
    let samples: [HabitSample]
    let color: Color
    var compact = false

    private var hasEntries: Bool { samples.contains { $0.entry != nil } }
    private var axisDates: [Date] {
        if samples.count <= 4 { return samples.map(\.date) }
        let last = samples.count - 1
        return [0, last / 3, last * 2 / 3, last].map { samples[$0].date }
    }
    private var domain: ClosedRange<Date> {
        let first = samples.first?.date ?? calendar.startOfDay(for: Date())
        let last = samples.last?.date ?? first
        return first...calendar.date(byAdding: .day, value: 1, to: last)!
    }

    var body: some View {
        Chart {
            if !compact {
                RuleMark(y: .value("Goal", 100))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(color.opacity(0.25))
            }
            ForEach(samples) { sample in
                if let entry = sample.entry {
                    if entry.fraction > 0 {
                        BarMark(x: .value("Day", sample.date, unit: .day), y: .value("Daily goal %", sample.fraction * 100),
                                width: samples.count < 7 ? .fixed(compact ? 10 : 22) : .ratio(0.7))
                            .foregroundStyle(color.gradient).cornerRadius(compact ? 2 : 4)
                    } else {
                        PointMark(x: .value("Day", sample.date, unit: .day), y: .value("Daily goal %", 3))
                            .symbol(entry.checkIn == .failed ? .cross : .circle)
                            .symbolSize(compact ? 10 : 24)
                            .foregroundStyle(entry.checkIn == .failed ? DayInInkTheme.secondary : color)
                    }
                }
            }
        }
        .chartXScale(domain: domain)
        .chartYScale(domain: 0...105)
        .chartXAxis {
            if !compact {
                AxisMarks(values: axisDates) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day()).font(.caption2)
                }
            }
        }
        .chartYAxis {
            if !compact {
                AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                    AxisGridLine().foregroundStyle(DayInInkTheme.background)
                    AxisValueLabel { Text("\(value.as(Int.self) ?? 0)%").font(.caption2) }
                }
            }
        }
        .chartPlotStyle { plot in
            plot.background(color.opacity(0.035)).clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .overlay {
            if !hasEntries {
                Text(compact ? "Your next chapter starts with a check-in" : "Check in to start your story")
                    .font(.caption).foregroundStyle(DayInInkTheme.secondary)
                    .lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center).padding(8).background(DayInInkTheme.paper, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daily progress chart. \(samples.filter { $0.entry != nil }.count) days shown, \(completionPercent(samples)) percent completion.")
    }
}
