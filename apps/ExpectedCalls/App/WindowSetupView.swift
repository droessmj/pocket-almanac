import SwiftUI
import ExpectedCallsCore

struct WindowSetupView: View {
    let windowID: UUID
    @Environment(ExpectedCallsModel.self) private var model

    var body: some View {
        Group {
            if let state = model.state, let window = state.windows.first(where: { $0.id == windowID }) {
                Form {
                    Section {
                        Label("You create the automations", systemImage: "wand.and.stars")
                            .font(.headline).foregroundStyle(.indigo)
                        Text("This app evaluates a saved window only when Shortcuts calls it. It cannot schedule background work or set a Phone option. Create two Time of Day automations for this occurrence, both set to Run Immediately.")
                        Text("For multiple future occurrences, keep a separate opening/closing pair for each. You may reuse a completed pair by updating both trigger times, Window ID and revision. Never repurpose an outstanding original closing automation.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }

                    Section("1 · Create the two triggers") {
                        Text("On iOS 27: open the shortcut in Shortcuts → Edit → Automation → Time of Day. Create an opening shortcut and a closing shortcut, each with its own Time of Day automation.")
                        Text("On earlier versions with the Automation tab: Shortcuts → Automation → + → Time of Day. Choose New Blank Automation or the equivalent action editor.")
                        Text("Use Daily/Every Day and Run Immediately for both. The intent checks the saved absolute dates, so repeats outside this window return noChange. No manual confirmation should be required at run time.")
                        triggerCard("Opening", date: window.start, symbol: "sunrise")
                        triggerCard("Closing", date: window.end, symbol: "moon")
                        Text("The trigger uses your device’s local clock. Recheck both trigger times after travel or a device time-zone change. For a window spanning a DST change, use the separately displayed offset for each boundary.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }

                    Section("2 · Add the intent to each") {
                        Text("Add the Expected Calls action “Evaluate Expected Calls”. Set Boundary to Opening in the opening automation and Closing in the closing automation. Enter these exact parameters in BOTH:")
                        ParameterValues(windowID: window.id, revision: window.revision)
                        Text("Window ID is Text; Revision is a Number. Do not use the label as the identifier. An edit changes the revision: update both automations and their trigger times before confirming setup again.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }

                    Section("3 · Branch on the returned text") {
                        Text("Immediately after the intent, use If actions to compare its returned Text exactly. Apply these same branches in BOTH automations:")
                        branch("allow", action: "Set Silence Unknown Callers Off", symbol: "phone.arrow.up.right")
                        branch("restoreSilence", action: "Set Silence Unknown Callers On", symbol: "phone.down")
                        branch("noChange", action: "Do nothing", symbol: "minus.circle")
                        Text("Use separate exact-match conditions (or nested Otherwise → If). Do not put an unconditional Phone-setting action after the branches. If your iOS version does not expose the required Set Silence Unknown Callers action, automatic switching is unavailable: use the manual guide instead and do not confirm this checklist.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }

                    Section("4 · Permit unattended runs") {
                        Text("On iOS 27, for each shortcut: Edit → Info → Privacy → Allow Running When Locked. Enable it if available, and resolve any permission prompts while unlocked. Keep Run Immediately enabled on both Time of Day automations.")
                        Text("Shortcuts, device power/lock state, OS restrictions, and Phone action availability can prevent execution. The app cannot verify the automations, their permissions, or the Phone setting.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }

                    if !state.sessions.isEmpty {
                        Section("Before changing an old pair") {
                            Text("Outstanding restore responsibility exists. Keep each original closing automation with its original Window ID and revision until it runs. If you need to silence calls immediately, restore manually; do not delete that closing path.")
                                .foregroundStyle(.orange)
                            NavigationLink("View manual restore instructions") { ManualCallControlsView() }
                        }
                    }

                    Section("5 · Confirm this revision") {
                        Button {
                            model.confirmSetup(windowID: window.id)
                        } label: {
                            Label(state.confirmedRevisions[window.id.uuidString] == window.revision ? "Setup confirmed for revision \(window.revision)" : "I configured both automations", systemImage: state.confirmedRevisions[window.id.uuidString] == window.revision ? "checkmark.circle.fill" : "checkmark.circle")
                        }
                        .accessibilityIdentifier("confirm-setup")
                        Text("Confirmation is your checklist record, not automatic verification. The opening intent returns noChange until this revision is confirmed. An intent evaluation records restore responsibility, not successful completion or readback of the following Phone action.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }

                    Section("Default: restore Silence") {
                        Text("After the last overlapping confirmed window closes, the closing intent returns restoreSilence. If another expected-call window is still in progress, it returns noChange and retains or transfers responsibility to that window’s close. The policy is Silence Unknown Callers ON—not an unknown previous state.")
                        Text("If an opening or closing automation is missed, returns an error, or its following Phone action fails, inspect the app’s last evaluation and use the manual guide. A late closing run can still restore Silence; an opening run outside its saved window cannot allow calls.")
                            .font(.footnote).foregroundStyle(.secondary)
                        NavigationLink("Allow now / Restore Silence manually") { ManualCallControlsView() }
                    }
                }
            } else {
                ContentUnavailableView("Window no longer saved", systemImage: "calendar.badge.minus")
            }
        }
        .navigationTitle("Shortcuts checklist")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func triggerCard(_ name: String, date: Date, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("\(name) · \(CallTime.trigger(date, in: .current)) device time", systemImage: symbol)
                .font(.subheadline.weight(.semibold))
            Text("Device (\(TimeZone.current.identifier)): \(CallTime.instant(date, in: .current))")
            Text("Chicago: \(CallTime.instant(date))")
        }
        .font(.footnote)
        .textSelection(.enabled)
        .padding(.vertical, 5)
    }

    private func branch(_ result: String, action: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("If result is \(result)").font(.system(.subheadline, design: .monospaced).weight(.semibold))
            Label(action, systemImage: symbol).font(.subheadline)
        }
        .textSelection(.enabled)
        .padding(.vertical, 4)
    }
}
