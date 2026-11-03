import SwiftUI
import ExpectedCallsCore

struct ExpectedCallsView: View {
    @Environment(ExpectedCallsModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @State private var editor: WindowEditorRequest?

    var body: some View {
        NavigationStack {
            Group {
                if let state = model.state {
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        windowList(state, now: context.date)
                    }
                } else {
                    ContentUnavailableView {
                        Label("Local data unavailable", systemImage: "externaldrive.badge.exclamationmark")
                    } description: {
                        Text("Saved data has not been overwritten. Restore Silence Unknown Callers manually if a window was in progress.")
                    } actions: {
                        Button("Try again") { model.reload() }
                    }
                }
            }
            .navigationTitle("Expected Calls")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Add window", systemImage: "plus") {
                        editor = WindowEditorRequest(window: newWindow())
                    }
                    .disabled(model.state == nil)
                    .accessibilityIdentifier("add-window")
                }
            }
            .sheet(item: $editor) { request in
                WindowEditor(window: request.window, isNew: true)
            }
            .alert("Couldn’t complete that change", isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )) {
                Button("OK") { model.errorMessage = nil }
            } message: {
                Text(model.errorMessage ?? "Please try again.")
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { model.reload() }
            }
        }
    }

    private func windowList(_ state: CallState, now: Date) -> some View {
        List {
            Section {
                Label("A little preparation. A quieter day.", systemImage: "phone.badge.waveform")
                    .font(.headline)
                    .foregroundStyle(.indigo)
                Text("Plan expected anonymous or unknown calls. Shortcuts—not this app—changes Silence Unknown Callers. This never guarantees that a call rings.")
                    .font(.subheadline)
                Label("America/Chicago", systemImage: "globe.americas")
                    .font(.subheadline.weight(.semibold))
                Text("Default after the last overlapping window: Silence Unknown Callers ON. Your previous Phone setting cannot be read or restored automatically.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                if state.windows.isEmpty {
                    ContentUnavailableView("No expected calls", systemImage: "calendar.badge.plus", description: Text("Add a future window, then configure its two Shortcuts automations."))
                }
                ForEach(state.windows.sorted { $0.start < $1.start }, id: \.id) { window in
                    NavigationLink {
                        WindowDetailView(windowID: window.id)
                    } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(window.label).font(.headline)
                            Text(CallTime.instant(window.start))
                            Text("Until \(CallTime.instant(window.end))")
                            HStack {
                                Label(scheduleStatus(window, now: now), systemImage: "calendar")
                                Spacer()
                                Text(state.confirmedRevisions[window.id.uuidString] == window.revision ? "Setup confirmed" : "Setup needed")
                                    .foregroundStyle(state.confirmedRevisions[window.id.uuidString] == window.revision ? Color.secondary : Color.orange)
                            }
                            .font(.caption.weight(.medium))
                        }
                        .font(.subheadline)
                        .padding(.vertical, 5)
                    }
                    .accessibilityIdentifier("window-\(window.id.uuidString)")
                }
            } header: {
                Text("Saved windows")
            } footer: {
                Text("A saved or currently scheduled window is not proof that a Phone setting changed. Setup confirmation records your checklist only.")
            }

            if !state.sessions.isEmpty {
                Section {
                    ForEach(state.sessions.indices, id: \.self) { index in
                        SessionSummary(session: state.sessions[index])
                    }
                } header: {
                    Text("Outstanding restore responsibility")
                } footer: {
                    Text("These are intent evaluations, not Phone-setting readback. Original closing details survive edits and cancellation. Keep those closing automations until evaluated; overlapping windows restore Silence only after the last one closes.")
                }
            }

            Section("Last intent evaluation") {
                Text(state.lastEvaluation ?? "No evaluation recorded yet.")
                    .font(.footnote)
                    .textSelection(.enabled)
            }

            Section {
                NavigationLink("Allow now / Restore Silence manually") { ManualCallControlsView() }
            } footer: {
                Text("Local-only. No account, contact access, notifications, background scheduling, or direct Phone-setting access.")
            }
        }
        .listStyle(.insetGrouped)
    }

    private func scheduleStatus(_ window: ExpectedCallWindow, now: Date) -> String {
        if now < window.start { return "Upcoming" }
        if now < window.end { return "Within saved time" }
        return "Ended"
    }

    private func newWindow() -> ExpectedCallWindow {
        if let seed = CallState.initial.windows.first, seed.start > .now {
            return ExpectedCallWindow(start: seed.start, end: seed.end)
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = CallTime.chicago
        let nextHour = calendar.nextDate(after: .now, matching: DateComponents(minute: 0, second: 0), matchingPolicy: .nextTime) ?? Date.now.addingTimeInterval(3600)
        return ExpectedCallWindow(start: nextHour, end: nextHour.addingTimeInterval(20 * 60))
    }
}

private struct WindowEditorRequest: Identifiable {
    let id = UUID()
    let window: ExpectedCallWindow
}

struct WindowDetailView: View {
    let windowID: UUID
    @Environment(ExpectedCallsModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var editing = false
    @State private var confirmingCancel = false

    var body: some View {
        Group {
            if let state = model.state, let window = state.windows.first(where: { $0.id == windowID }) {
                Form {
                    Section("America/Chicago · fixed time zone") {
                        LabeledContent("Opens") { Text(CallTime.instant(window.start)).multilineTextAlignment(.trailing) }
                        LabeledContent("Closes") { Text(CallTime.instant(window.end)).multilineTextAlignment(.trailing) }
                        Text("These are absolute instants. Device time-zone changes do not move the saved window, but you must update Shortcuts trigger times if your device time zone changes.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Section("Shortcuts setup") {
                        Label(state.confirmedRevisions[window.id.uuidString] == window.revision ? "Checklist confirmed for revision \(window.revision)" : "Setup not confirmed for revision \(window.revision)", systemImage: "checklist")
                            .accessibilityIdentifier("setup-status")
                            .accessibilityValue(state.confirmedRevisions[window.id.uuidString] == window.revision ? "confirmed" : "needsSetup")
                        NavigationLink("Set up opening & closing automations") {
                            WindowSetupView(windowID: window.id)
                        }
                        .accessibilityIdentifier("setup-window")
                        Text("Editing invalidates this window’s setup confirmation. Update both automations with its new times and revision, then confirm again. Other saved windows are unchanged.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Section("Intent parameters") {
                        ParameterValues(windowID: window.id, revision: window.revision)
                    }
                    if !state.sessions.isEmpty {
                        Section("Keep original closing automations") {
                            ForEach(state.sessions.indices, id: \.self) { index in
                                if state.sessions[index].windowID == window.id {
                                    SessionSummary(session: state.sessions[index])
                                }
                            }
                            Text("An edit or cancellation does not erase restore responsibility. Do not replace an outstanding original closing automation. Restore manually now if needed; keep its original close, which is safe to run again.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    Section {
                        NavigationLink("Allow now / Restore Silence manually") { ManualCallControlsView() }
                        Button("Edit window", systemImage: "pencil") { editing = true }
                            .accessibilityIdentifier("edit-window")
                        Button("Cancel window", role: .destructive) { confirmingCancel = true }
                            .accessibilityIdentifier("cancel-window")
                    }
                }
                .navigationTitle(window.label)
                .navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $editing) { WindowEditor(window: window, isNew: false) }
                .confirmationDialog("Cancel this expected-call window?", isPresented: $confirmingCancel, titleVisibility: .visible) {
                    Button("Cancel window", role: .destructive) {
                        model.cancel(windowID: window.id)
                        if model.state?.windows.contains(where: { $0.id == window.id }) == false { dismiss() }
                    }
                } message: {
                    Text("Disable this window’s opening automation. If opening already ran, turn Silence Unknown Callers ON manually now unless another expected-call window is in progress. Keep the original closing automation: cancellation does not change Phone settings or discard its restore responsibility.")
                }
            } else {
                ContentUnavailableView("Window no longer saved", systemImage: "calendar.badge.minus")
            }
        }
    }
}

struct WindowEditor: View {
    let window: ExpectedCallWindow
    let isNew: Bool
    @Environment(ExpectedCallsModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var label: String
    @State private var start: Date
    @State private var end: Date
    @State private var validationMessage: String?

    init(window: ExpectedCallWindow, isNew: Bool) {
        self.window = window
        self.isNew = isNew
        _label = State(initialValue: window.label)
        _start = State(initialValue: window.start)
        _end = State(initialValue: window.end)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Window label", text: $label)
                        .accessibilityIdentifier("window-label")
                    DatePicker("Start", selection: $start, displayedComponents: [.date, .hourAndMinute])
                        .accessibilityIdentifier("window-start")
                    DatePicker("End", selection: $end, displayedComponents: [.date, .hourAndMinute])
                        .accessibilityIdentifier("window-end")
                } header: {
                    Label("America/Chicago", systemImage: "globe.americas")
                } footer: {
                    Text("Fixed Chicago time zone, not your device’s time zone. Choose a future start and a later end. Multiple windows may overlap; the last closing window restores Silence.")
                }
                Section("Selected absolute instants") {
                    Text("Start: \(CallTime.instant(start))")
                    Text("End: \(CallTime.instant(end))")
                    Text("Daylight saving time can skip or repeat wall-clock times. The date pickers select actual instants; check the numeric UTC offsets above, especially during a repeated hour. Once saved, travel or DST does not shift these instants.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if !isNew {
                    Section {
                        Text("Saving an edit changes this window’s revision and requires updating both Shortcuts automations. An existing session keeps its original closing parameters; do not replace that close until it runs.")
                            .font(.footnote)
                    }
                }
                if let validationMessage {
                    Section { Text(validationMessage).foregroundStyle(.red).accessibilityIdentifier("window-validation-error") }
                }
            }
            .environment(\.timeZone, CallTime.chicago)
            .navigationTitle(isNew ? "Add expected call" : "Edit expected call")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("save-window")
                }
            }
        }
    }

    private func save() {
        guard start > .now else {
            validationMessage = "Choose a start time in the future. Use the manual controls guide for an immediate change."
            return
        }
        guard end > start else {
            validationMessage = "End must be after start."
            return
        }
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        let updated = ExpectedCallWindow(id: window.id, label: trimmedLabel.isEmpty ? "Expected call" : trimmedLabel, start: start, end: end, timeZoneIdentifier: "America/Chicago", revision: window.revision)
        if model.save(updated) {
            dismiss()
        } else {
            validationMessage = model.errorMessage
            model.errorMessage = nil
        }
    }
}

struct ParameterValues: View {
    let windowID: UUID
    let revision: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Window ID").font(.caption).foregroundStyle(.secondary)
            Text(windowID.uuidString).font(.system(.footnote, design: .monospaced)).textSelection(.enabled)
            Text("Revision: \(revision)").font(.system(.subheadline, design: .monospaced)).textSelection(.enabled)
            ShareLink(item: "Window ID: \(windowID.uuidString)\nRevision: \(revision)") {
                Label("Share parameters", systemImage: "square.and.arrow.up")
            }
        }
        .padding(.vertical, 3)
    }
}

struct SessionSummary: View {
    let session: CallSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Original close still matters", systemImage: "arrow.uturn.backward.circle")
                .font(.subheadline.weight(.semibold))
            Text("Chicago: \(CallTime.instant(session.end))")
            Text("Device (\(TimeZone.current.identifier)): \(CallTime.instant(session.end, in: .current))")
            Text("Boundary: Closing").font(.footnote)
            ParameterValues(windowID: session.windowID, revision: session.revision)
        }
        .font(.footnote)
        .padding(.vertical, 3)
    }
}

struct ManualCallControlsView: View {
    var body: some View {
        Form {
            Section("Allow now · manual") {
                Text("Open Settings → Apps → Phone. Find Silence Unknown Callers and turn it OFF. On newer versions, choose Screen Unknown Callers → Never if that is the equivalent option shown.")
                Text("On iOS 17, open Settings → Phone instead. Settings labels vary by iOS version. This app does not open a private settings URL or change the setting itself.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Restore Silence · manual") {
                Text("Return to the same Phone setting and turn Silence Unknown Callers ON, or choose the equivalent Silence option shown on your iOS version.")
                Text("Restore after the last overlapping expected-call window. This is the app’s explicit default, not a readback of your previous setting. Keep outstanding closing automations even after a manual restore.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("What this cannot promise") {
                Text("An unknown or anonymous call may still be blocked, silenced, screened, or sent to voicemail by Focus, carrier filtering, blocking, connectivity, or other settings. Changing this one setting does not guarantee ringing.")
                Text("Manual changes are not observable by this app. They do not create, finish, or confirm an intent session.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Manual Phone controls")
        .navigationBarTitleDisplayMode(.inline)
    }
}
