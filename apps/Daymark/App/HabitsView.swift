import SwiftUI
import HabitKit

struct HabitsView: View {
    @Environment(HabitStore.self) private var store
    @State private var editing: Habit?
    @State private var showAbout = false
    let addHabit: () -> Void

    private var archived: [Habit] { store.archive.habits.filter(\.isArchived) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your habits").font(DaymarkTheme.handwriting(32, relativeTo: .title))
                        Text("Small promises. Lasting change.").font(DaymarkTheme.handwriting(18, relativeTo: .subheadline)).foregroundStyle(DaymarkTheme.secondary)
                    }
                    Spacer()
                    Button { showAbout = true } label: {
                        Image(systemName: "info.circle").font(.title3).frame(width: 44, height: 44)
                    }.accessibilityLabel("About Daymark and your data")
                }.padding(.top, 18)

                VStack(spacing: 12) {
                    ForEach(store.activeHabits) { habit in row(habit) }
                }
                if store.activeHabits.isEmpty {
                    EmptyHabits(title: "A little space for growth", message: "Add a habit you’d like to give attention to.",
                                actionTitle: "Add a habit", action: addHabit)
                }
                Button(action: addHabit) {
                    Label("Add a new habit", systemImage: "plus")
                        .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(18)
                        .background(DaymarkTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(DaymarkTheme.accent.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [5])))
                }

                if !archived.isEmpty {
                    Text("ARCHIVED").font(.system(size: 11, weight: .semibold)).tracking(2)
                        .foregroundStyle(DaymarkTheme.secondary).padding(.top, 8)
                    Text("Your history is still here. Restore a habit whenever you’re ready.")
                        .font(.caption).foregroundStyle(DaymarkTheme.secondary)
                    VStack(spacing: 12) { ForEach(archived) { habit in row(habit) } }
                }
            }
            .padding(.horizontal, 22).padding(.bottom, 24)
        }
        .sheet(item: $editing) { habit in HabitEditor(habit: habit) }
        .sheet(isPresented: $showAbout) { about }
    }

    private func row(_ habit: Habit) -> some View {
        HStack(spacing: 12) {
            NavigationLink(value: habit) {
                HStack(spacing: 12) {
                    HabitIcon(habit: habit)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(habit.name).font(DaymarkTheme.handwriting(20, relativeTo: .headline)).foregroundStyle(DaymarkTheme.ink)
                        Text(habit.kind == .checkIn ? "Daily · pass / fail" : "Daily · \(amount(habit.target)) \(habit.unit)")
                            .font(.caption).foregroundStyle(DaymarkTheme.secondary)
                    }
                    Spacer(minLength: 0)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
            Menu {
                Button("Edit habit", systemImage: "pencil") { editing = habit }
                Button(habit.isArchived ? "Restore habit" : "Archive habit", systemImage: "archivebox") { store.archiveHabit(habit) }
            } label: {
                Image(systemName: "ellipsis").foregroundStyle(DaymarkTheme.secondary).frame(width: 44, height: 44)
            }.accessibilityLabel("Options for \(habit.name)")
        }
        .padding(14).paperCard()
    }

    private var about: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "pencil.and.outline").font(.system(size: 44, weight: .light)).foregroundStyle(DaymarkTheme.accent)
                        Text("Daymark").font(DaymarkTheme.handwriting(36, relativeTo: .largeTitle))
                        Text("A little better, every day.").foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity).padding(.vertical, 18)
                }
                Section("Your data") {
                    Text("Your habits and check-ins are saved on this iPhone. No account, ads, or analytics. Your app data can be included in your iPhone’s device backup.")
                }
                Section("A few helpful things") {
                    Text("Tap + on a progress habit to add its quick-add amount. Pass / fail habits start passed; tap the checkmark to mark a failure, or tap × to restore a pass.")
                    Text("Open a habit to record a failed day, enter an exact total, or edit a past check-in. You can also touch and hold a daily card for these actions.")
                    Text("Trends count days from when a habit was created. Pass / fail days count as passed unless you mark a failure. Today can still be in progress.")
                    Text("Archiving keeps your history. Deleting a habit permanently removes its check-ins.")
                }
            }
            .navigationTitle("Made for small steps").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showAbout = false } } }
        }
    }
}
