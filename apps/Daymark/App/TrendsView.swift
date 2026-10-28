import SwiftUI
import Charts
import HabitKit

struct TrendsView: View {
    @Environment(HabitStore.self) private var store
    @State private var days = 30

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Little steps add up.").font(DaymarkTheme.handwriting(31, relativeTo: .title))
                    Text("Your progress, one habit at a time.").font(DaymarkTheme.handwriting(18, relativeTo: .subheadline)).foregroundStyle(DaymarkTheme.secondary)
                }.padding(.top, 18)
                periodPicker(days: $days)

                if store.activeHabits.isEmpty {
                    EmptyHabits(title: "Your story starts here", message: "Add a habit, then check in to see your progress grow.")
                }
                ForEach(store.activeHabits) { habit in
                    let samples = store.archive.samples(for: habit, days: days)
                    let completed = samples.filter { $0.entry?.isComplete == true }.count
                    NavigationLink(value: habit) {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack(spacing: 12) {
                                HabitIcon(habit: habit, size: 42)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(habit.name).font(DaymarkTheme.handwriting(21, relativeTo: .headline))
                                        .foregroundStyle(DaymarkTheme.ink)
                                    Text("\(completed) of \(samples.count) \(samples.count == 1 ? "day" : "days") completed")
                                        .font(.caption).foregroundStyle(DaymarkTheme.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right").font(.caption.weight(.semibold)).foregroundStyle(habit.color.tint)
                            }
                            TrendChart(samples: samples, color: habit.color.tint, compact: true)
                                .frame(height: 68)
                            HStack {
                                Text("\(completionPercent(samples))% completion")
                                    .font(.caption.weight(.semibold)).foregroundStyle(habit.color.tint)
                                Spacer()
                                Label("\(store.archive.streak(for: habit)) day streak", systemImage: "sparkle")
                                    .font(.caption).foregroundStyle(DaymarkTheme.secondary)
                            }
                        }.daymarkCard()
                    }.buttonStyle(.plain)
                }
                Text("Trends include today and start on each habit’s creation date. Pass/fail habits count as passed unless marked failed. Numeric habits need recorded progress.")
                    .font(.caption).foregroundStyle(DaymarkTheme.secondary).padding(.bottom, 8)
            }.padding(.horizontal, 22).padding(.bottom, 18)
        }
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
        let first = samples.first?.date ?? Calendar.current.startOfDay(for: Date())
        let last = samples.last?.date ?? first
        return first...Calendar.current.date(byAdding: .day, value: 1, to: last)!
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
                            .foregroundStyle(entry.checkIn == .failed ? DaymarkTheme.secondary : color)
                    }
                }
            }
        }
        .chartXScale(domain: domain)
        .chartYScale(domain: 0...105)
        .chartXAxis {
            if !compact {
                AxisMarks(values: axisDates) { _ in
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day()).font(.system(size: 9))
                }
            }
        }
        .chartYAxis {
            if !compact {
                AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                    AxisGridLine().foregroundStyle(DaymarkTheme.background)
                    AxisValueLabel { Text("\(value.as(Int.self) ?? 0)%").font(.system(size: 9)) }
                }
            }
        }
        .chartPlotStyle { plot in
            plot.background(color.opacity(0.035)).clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .overlay {
            if !hasEntries {
                Text(compact ? "Your next chapter starts with a check-in" : "Check in to start your story")
                    .font(.system(size: compact ? 10 : 12)).foregroundStyle(DaymarkTheme.secondary)
                    .padding(8).background(.white.opacity(0.85), in: Capsule())
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daily progress chart. \(samples.filter { $0.entry != nil }.count) days shown, \(completionPercent(samples)) percent completion.")
    }
}
