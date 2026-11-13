import SwiftUI
import HabitKit

struct HabitsView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var editing: Habit?
    @State private var showAbout = false
    @State private var errorMessage: String?
    let addHabit: () -> Void

    private var archived: [Habit] { store.archive.habits.filter(\.isArchived) }

    var body: some View {
        ScrollView {
            let activeHabits = store.activeHabits
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your habits").font(DayInInkTheme.handwriting(32, relativeTo: .title))
                        Text("Small promises. Lasting change.").font(DayInInkTheme.handwriting(18, relativeTo: .subheadline)).foregroundStyle(DayInInkTheme.secondary)
                    }
                    Spacer()
                    Button { showAbout = true } label: {
                        Image(systemName: "info.circle").font(.title3).frame(width: 44, height: 44)
                    }.accessibilityLabel("About Day in Ink and your data")
                }.padding(.top, 18)

                VStack(spacing: 12) {
                    ForEach(activeHabits) { habit in row(habit, activeHabits: activeHabits) }
                }
                if activeHabits.isEmpty {
                    EmptyHabits(title: "A little space for growth", message: "Add a habit you’d like to give attention to.",
                                actionTitle: "Add a habit", action: addHabit)
                }
                Button(action: addHabit) {
                    Label("Add a new habit", systemImage: "plus")
                        .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(18)
                        .background(DayInInkTheme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(DayInInkTheme.accent.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [5])))
                }

                if !archived.isEmpty {
                    Text("ARCHIVED").font(.caption.weight(.semibold)).tracking(2)
                        .foregroundStyle(DayInInkTheme.secondary).padding(.top, 8)
                    Text("Your history is still here. Restore a habit whenever you’re ready.")
                        .font(.caption).foregroundStyle(DayInInkTheme.secondary)
                    VStack(spacing: 12) { ForEach(archived) { habit in row(habit, activeHabits: activeHabits) } }
                }
            }
            .padding(.horizontal, 22).padding(.bottom, 24)
        }
        .sheet(item: $editing) { habit in HabitEditor(habit: habit) }
        .sheet(isPresented: $showAbout) { about }
        .mutationError($errorMessage)
    }

    private func row(_ habit: Habit, activeHabits: [Habit]) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
        return layout {
            if !habit.isArchived {
                HabitReorderHandle(habit: habit, habits: activeHabits, move: moveHabit)
            }
            NavigationLink(value: habit) {
                HStack(spacing: 12) {
                    HabitIcon(habit: habit)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(habit.name).font(DayInInkTheme.handwriting(20, relativeTo: .headline)).foregroundStyle(DayInInkTheme.ink)
                            .lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                        Text(habit.kind == .checkIn ? "Daily · pass / fail" : "Daily · \(amount(habit.target)) \(habit.unit)")
                            .font(.caption).foregroundStyle(DayInInkTheme.secondary)
                            .lineLimit(nil).fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
            Menu {
                if !habit.isArchived {
                    HabitMoveActions(habit: habit, habits: activeHabits, move: moveHabit)
                }
                Button("Edit habit", systemImage: "pencil") { editing = habit }
                Button(habit.isArchived ? "Restore habit" : "Archive habit", systemImage: "archivebox") {
                    Task {
                        do { try await store.archiveHabit(habit) }
                        catch { errorMessage = error.localizedDescription }
                    }
                }
            } label: {
                Image(systemName: "ellipsis").foregroundStyle(DayInInkTheme.secondary).frame(width: 44, height: 44)
            }.accessibilityLabel("Options for \(habit.name)")
        }
        .padding(14).paperCard()
        .habitDropDestination(habit, habits: store.archive.habits, move: moveHabit)
    }

    private func moveHabit(_ habitID: UUID, _ targetID: UUID) {
        Task {
            do { try await store.moveHabit(habitID, to: targetID) }
            catch { errorMessage = error.localizedDescription }
        }
    }

    private var about: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "pencil.and.outline").font(.system(size: 44, weight: .light)).foregroundStyle(DayInInkTheme.accent)
                        Text("Day in Ink").font(DayInInkTheme.handwriting(36, relativeTo: .largeTitle))
                        Text("A little better, every day.").foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity).padding(.vertical, 18)
                }
                Section("Your data") {
                    Text("Your habits and check-ins are saved on this iPhone. No account, ads, or analytics. Your app data can be included in your iPhone’s device backup.")
                    NavigationLink("Export and import", destination: DataTransferView())
                        .accessibilityIdentifier("data-transfer")
                }
                Section("A few helpful things") {
                    Text("Tap + on a progress habit to add its quick-add amount. Choose whether each pass / fail habit starts passed or failed in Edit habit. Tap its checkmark or × to switch the day's result.")
                    Text("Open a habit to record a failed day, enter an exact total, or edit a past check-in. You can also touch and hold a daily card for these actions.")
                    Text("Drag a habit’s reorder handle onto another habit to change its position on Today, Habits, and Trends. You can also choose Move up or Move down from the habit’s actions. Today moves within the habits shown by its current filter.")
                    Text("Trends count days from each habit’s saved start day. Unrecorded pass / fail days use that habit’s daily default. Changing the default updates unrecorded days; explicit check-ins stay as logged. Today can still be in progress.")
                    Text("Archiving keeps your history. Deleting a habit permanently removes its check-ins.")
                }
                Section("Support and privacy") {
                    Link("Help & Support", destination: URL(string: "https://apps.droessmj.com/day-in-ink/support.html")!)
                    Link("Privacy Policy", destination: URL(string: "https://apps.droessmj.com/day-in-ink/privacy.html")!)
                }
            }
            .navigationTitle("Made for small steps").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showAbout = false } } }
        }
    }
}
