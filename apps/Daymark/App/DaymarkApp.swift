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
        case .today: "square.grid.2x2.fill"
        case .trends: "chart.xyaxis.line"
        case .habits: "checklist"
        }
    }
}

struct RootView: View {
    @Environment(HabitStore.self) private var store
    @State private var tab = AppTab.today
    @State private var addingHabit = false

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
                    .background(DaymarkTheme.background)
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
                }
            }
        }
        .foregroundStyle(DaymarkTheme.ink)
        .sheet(isPresented: $addingHabit) { HabitEditor() }
        .alert("Couldn’t save or load", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) { Button("OK") { store.errorMessage = nil } }
        message: { Text(store.errorMessage ?? "Please try again.") }
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            Button { addingHabit = true } label: {
                Image(systemName: "plus").font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(.white).frame(width: 46, height: 46)
                    .background(DaymarkTheme.accent.gradient, in: Circle())
            }
            .accessibilityLabel("Add habit")
            .padding(.horizontal, 10)

            ForEach(AppTab.allCases, id: \.self) { item in
                Button { tab = item } label: {
                    VStack(spacing: 5) {
                        Image(systemName: item.icon).font(.system(size: 20, weight: .semibold))
                        Text(item.rawValue).font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(tab == item ? DaymarkTheme.accent : DaymarkTheme.secondary)
                    .frame(maxWidth: .infinity).frame(minHeight: 54)
                    .background(tab == item ? DaymarkTheme.accent.opacity(0.08) : .clear,
                                in: RoundedRectangle(cornerRadius: 20))
                }
                .accessibilityAddTraits(tab == item ? .isSelected : [])
            }
        }
        .padding(8)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white, lineWidth: 1.5))
        .shadow(color: .black.opacity(0.04), radius: 14, y: 4)
        .padding(.horizontal, 22).padding(.top, 10).padding(.bottom, 6)
        .background(DaymarkTheme.background.opacity(0.96))
    }
}

