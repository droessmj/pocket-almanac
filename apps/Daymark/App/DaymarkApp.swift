import SwiftUI
import HabitKit

@main
struct DaymarkApp: App {
    @State private var store = HabitStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(DaymarkTheme.accent)
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

    var body: some View {
        @Bindable var store = store
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
            } else {
                ContentUnavailableView {
                    Label("Couldn’t open your habits", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text("Your saved data has been kept. Try opening it again.")
                } actions: {
                    Button("Try again") { store.load() }.buttonStyle(.borderedProminent)
                    Button("Import a backup") { showDataTransfer = true }
                }
            }
        }
        .foregroundStyle(DaymarkTheme.ink)
        .sheet(isPresented: $addingHabit) { HabitEditor() }
        .sheet(isPresented: $showDataTransfer) {
            NavigationStack {
                DataTransferView()
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showDataTransfer = false } } }
            }
        }
        .alert("Couldn’t save or load", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) { Button("OK") { store.errorMessage = nil } }
        message: { Text(store.errorMessage ?? "Please try again.") }
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(AppTab.allCases, id: \.self) { item in
                Button { tab = item } label: {
                    VStack(spacing: 5) {
                        Image(systemName: item.icon).font(.system(size: 20, weight: .semibold))
                        Text(item.rawValue).font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(tab == item ? DaymarkTheme.accent : DaymarkTheme.secondary)
                    .frame(maxWidth: .infinity).frame(minHeight: 54)
                    .background(tab == item ? DaymarkTheme.accent.opacity(0.08) : .clear,
                                in: RoundedRectangle(cornerRadius: 8))
                }
                .accessibilityAddTraits(tab == item ? .isSelected : [])
                .accessibilityIdentifier("tab-\(item.rawValue.lowercased())")
            }
            Button { addingHabit = true } label: {
                Image(systemName: "plus").font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(.white).frame(width: 46, height: 46)
                    .background(DaymarkTheme.accent, in: RoundedRectangle(cornerRadius: 8))
            }
            .accessibilityLabel("Add habit")
            .accessibilityIdentifier("add-habit")
            .padding(.leading, 12)


        }
        .padding(.horizontal, 20).padding(.vertical, 10)
        .background { PaperSurface().ignoresSafeArea() }
        .overlay(alignment: .top) {
            Rectangle().fill(DaymarkTheme.ink.opacity(0.1)).frame(height: 1)
        }
    }
}
