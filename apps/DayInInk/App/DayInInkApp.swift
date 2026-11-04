import SwiftUI
import UIKit
import HabitKit

@main
struct DayInInkApp: App {
    @State private var store = HabitStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(DayInInkTheme.accent)
                .preferredColorScheme(.light)
        }
    }
}

private enum AppTab: String, CaseIterable {
    case today = "Today", trends = "Trends", habits = "Habits"

    var icon: String {
        switch self {
        case .today: "sun.horizon"
        case .trends: "chart.xyaxis.line"
        case .habits: "checklist"
        }
    }
}

struct RootView: View {
    @Environment(HabitStore.self) private var store
    @State private var tab = AppTab.today
    @State private var addingHabit = false
    @State private var showDataTransfer = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var calendar = habitCalendar()

    var body: some View {
        Group {
            if store.ready {
                NavigationStack {
                    Group {
                        switch tab {
                        case .today: TodayView(addHabit: { addingHabit = true })
                        case .trends: TrendsView()
                        case .habits: HabitsView(addHabit: { addingHabit = true })
                        }
                    }
                    .toolbar(.hidden, for: .navigationBar)
                    .background { PaperSurface().ignoresSafeArea() }
                    .safeAreaInset(edge: .bottom, spacing: 0) { tabBar }
                    .navigationDestination(for: Habit.self) { habit in HabitDetailView(habitID: habit.id) }
                }
            } else if store.isLoading {
                ProgressView("Opening your habits…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView {
                    Label("Couldn’t open your habits", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text(store.errorMessage ?? "Your saved data has been kept. Try opening it again.")
                } actions: {
                    Button("Try again") { Task { await store.load() } }.buttonStyle(.borderedProminent)
                    Button("Import a backup") { showDataTransfer = true }
                    Link("Help & Support", destination: URL(string: "https://apps.droessmj.com/day-in-ink/support.html")!)
                    Link("Privacy Policy", destination: URL(string: "https://apps.droessmj.com/day-in-ink/privacy.html")!)
                }
            }
        }
        .foregroundStyle(DayInInkTheme.ink)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { calendar = habitCalendar() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            calendar = habitCalendar()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name.NSSystemTimeZoneDidChange)) { _ in
            calendar = habitCalendar()
        }
        .sheet(isPresented: $addingHabit) { HabitEditor() }
        .sheet(isPresented: $showDataTransfer) {
            NavigationStack {
                DataTransferView()
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showDataTransfer = false } } }
            }
        }
        .environment(\.calendar, calendar)
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            if dynamicTypeSize.isAccessibilitySize {
                Menu {
                    ForEach(AppTab.allCases, id: \.self) { item in
                        Button { tab = item } label: { Label(item.rawValue, systemImage: item.icon) }
                            .accessibilityIdentifier("tab-\(item.rawValue.lowercased())")
                    }
                } label: {
                    Label(tab.rawValue, systemImage: tab.icon)
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityLabel("Navigate, \(tab.rawValue) selected")
                .accessibilityIdentifier("tab-navigation")
            } else {
                ForEach(AppTab.allCases, id: \.self) { item in
                    Button { tab = item } label: {
                        VStack(spacing: 5) {
                            Image(systemName: item.icon).font(.system(size: 20, weight: .semibold))
                            Text(item.rawValue).font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(tab == item ? DayInInkTheme.accent : DayInInkTheme.secondary)
                        .frame(maxWidth: .infinity).frame(minHeight: 54)
                        .background(tab == item ? DayInInkTheme.accent.opacity(0.08) : .clear,
                                    in: RoundedRectangle(cornerRadius: 8))
                    }
                    .accessibilityAddTraits(tab == item ? .isSelected : [])
                    .accessibilityIdentifier("tab-\(item.rawValue.lowercased())")
                }
            }
            Button { addingHabit = true } label: {
                Image(systemName: "plus").font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(.white).frame(width: 46, height: 46)
                    .background(DayInInkTheme.accent, in: RoundedRectangle(cornerRadius: 8))
            }
            .accessibilityLabel("Add habit")
            .accessibilityIdentifier("add-habit")
            .padding(.leading, 12)


        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background { PaperSurface().ignoresSafeArea() }
        .overlay(alignment: .top) {
            Rectangle().fill(DayInInkTheme.ink.opacity(0.1)).frame(height: 1)
        }
    }
}
