import SwiftUI
import HabitKit

struct HabitsView: View {
    @Environment(HabitStore.self) private var store
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var editing: Habit?
    @State private var showAbout = false
    @State private var errorMessage: String?
    @State private var dropTargetID: UUID?
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

                if activeHabits.count > 1 {
                    Label("Touch and hold a handle, then drag to reorder.", systemImage: "arrow.up.arrow.down")
                        .font(.caption)
                        .foregroundStyle(DayInInkTheme.secondary)
                }
                VStack(spacing: 12) {
                    ForEach(activeHabits) { habit in row(habit, activeHabits: activeHabits) }
                }
                .animation(reduceMotion ? nil : .snappy(duration: 0.25), value: activeHabits)
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
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(DayInInkTheme.accent.opacity(dropTargetID == habit.id ? 0.75 : 0), lineWidth: 2)
                .allowsHitTesting(false)
        }
        .scaleEffect(dropTargetID == habit.id && !reduceMotion ? 1.02 : 1)
        .shadow(color: DayInInkTheme.ink.opacity(dropTargetID == habit.id ? 0.12 : 0),
                radius: 10, y: 4)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.16), value: dropTargetID == habit.id)
        .habitDropDestination(habit, habits: store.archive.habits, move: moveHabit) { targeted in
            if targeted { dropTargetID = habit.id }
            else if dropTargetID == habit.id { dropTargetID = nil }
        }
    }

    private func moveHabit(_ habitID: UUID, _ targetID: UUID) {
        dropTargetID = nil
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
                    Text("On Habits, touch and hold a reorder handle, then drag onto another habit. The highlighted card marks the destination. You can also choose Move up or Move down from a habit’s actions. Your saved order appears on Today, Habits, and Trends.")
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

private struct HabitReorderHandle: View {
    let habit: Habit
    let habits: [Habit]
    let move: (UUID, UUID) -> Void

    var body: some View {
        Image(systemName: "line.3.horizontal")
            .font(.body.weight(.semibold))
            .foregroundStyle(DayInInkTheme.accent)
            .frame(width: 44, height: 44)
            .background(DayInInkTheme.accent.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
            .contentShape(Rectangle())
            .draggable(habit.id.uuidString) {
                HStack(spacing: 12) {
                    HabitIcon(habit: habit)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(habit.name)
                            .font(DayInInkTheme.handwriting(21, relativeTo: .headline))
                            .foregroundStyle(DayInInkTheme.ink)
                        Text("Move to a new position")
                            .font(.caption)
                            .foregroundStyle(DayInInkTheme.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundStyle(DayInInkTheme.accent)
                }
                .frame(width: 260, alignment: .leading)
                .padding(16)
                .background(DayInInkTheme.paper, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(DayInInkTheme.accent.opacity(0.2)))
                .shadow(color: DayInInkTheme.ink.opacity(0.18), radius: 14, y: 7)
            }
            .accessibilityIdentifier("reorder-\(habit.name)")
            .accessibilityLabel("Reorder \(habit.name)")
            .accessibilityHint("Drag onto another habit, or use the Move up and Move down actions.")
            .accessibilityActions {
                HabitMoveActions(habit: habit, habits: habits, move: move)
            }
    }
}

private struct HabitMoveActions: View {
    let habit: Habit
    let habits: [Habit]
    let move: (UUID, UUID) -> Void

    var body: some View {
        if let index = habits.firstIndex(where: { $0.id == habit.id }) {
            Button("Move up", systemImage: "arrow.up") {
                if index > habits.startIndex { move(habit.id, habits[index - 1].id) }
            }
            .disabled(index == habits.startIndex)
            .accessibilityIdentifier("move-up-\(habit.name)")
            Button("Move down", systemImage: "arrow.down") {
                if index < habits.endIndex - 1 { move(habit.id, habits[index + 1].id) }
            }
            .disabled(index == habits.endIndex - 1)
            .accessibilityIdentifier("move-down-\(habit.name)")
        }
    }
}

private extension View {
    @ViewBuilder
    func habitDropDestination(_ habit: Habit, habits: [Habit],
                              move: @escaping (UUID, UUID) -> Void,
                              isTargeted: @escaping (Bool) -> Void) -> some View {
        if habit.isArchived {
            self
        } else {
            self.contentShape(Rectangle()).dropDestination(for: String.self, action: { items, _ in
                guard items.count == 1,
                      let sourceID = UUID(uuidString: items[0]),
                      sourceID != habit.id,
                      habits.contains(where: { $0.id == sourceID && !$0.isArchived }),
                      habits.contains(where: { $0.id == habit.id && !$0.isArchived }) else { return false }
                move(sourceID, habit.id)
                return true
            }, isTargeted: isTargeted)
        }
    }
}
