// Copyright (c) 2026 Michael Droessler
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

import SwiftUI

@main
struct SiftApp: App {
    @State private var setupDone = (UserDefaults(suiteName: Sift.appGroup)?.bool(forKey: "setupDone")) ?? false
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if setupDone {
                    TabView {
                        Tab("Keywords", systemImage: "text.badge.xmark") { KeywordsView() }
                        Tab("Activity", systemImage: "list.bullet.rectangle") { ActivityView() }
                    }
                } else {
                    SetupView {
                        setupDone = true
                        UserDefaults(suiteName: Sift.appGroup)?.set(true, forKey: "setupDone")
                    }
                }
            }
            .onChange(of: scenePhase, initial: true) { _, phase in
                if phase == .active {
                    do { _ = try ActivityLog.load() }
                    catch { ActivityLog.report(error) }
                }
            }
        }
    }
}

struct SetupView: View {
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "funnel.fill").font(.system(size: 64)).foregroundStyle(.indigo)
            Text("Set up Sift").font(.title.bold())
            VStack(alignment: .leading, spacing: 10) {
                LabeledContent("1", value: "In iPhone Settings, go to Apps → Messages → Text Message Filter and choose Sift.")
                LabeledContent("2", value: "Add the keywords you want to block. Texts containing them go silently to Junk.")
                LabeledContent("3", value: "Review recent activity and the reasons for matches in the Activity tab.")
            }
            .font(.subheadline)
            Text("Works on SMS/MMS from numbers not in your Contacts. Activity saves sender, time, verdict, and matched keyword on this iPhone. Full message text is never stored.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Get started", action: onDone)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(24)
    }
}

struct KeywordsView: View {
    @State private var keywords = KeywordStore.load()
    @State private var draft = ""
    @State private var options = KeywordStore.loadOptions()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("Add keyword or phrase", text: $draft)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit(add)
                        Button("Add", action: add).disabled(trimmedDraft.isEmpty)
                    }
                } footer: {
                    Text("Texts from unknown senders containing any keyword go silently to Spam. Senders in Contacts and iMessage are never filtered.")
                }
                Section {
                    Toggle("Match case", isOn: $options.matchCase)
                    Toggle("Match accents", isOn: $options.matchAccents)
                    Toggle("Whole words only", isOn: $options.wholeWords)
                } header: {
                    Text("Matching")
                } footer: {
                    Text(matchingSummary)
                }
                .onChange(of: options) { _, new in KeywordStore.save(new) }
                Section("Keywords") {
                    if keywords.isEmpty {
                        Text("No keywords yet.").foregroundStyle(.secondary)
                    }
                    ForEach(keywords, id: \.self) { Text($0) }
                        .onDelete { keywords.remove(atOffsets: $0); KeywordStore.save(keywords) }
                }
            }
            .navigationTitle("Sift")
        }
    }

    private var trimmedDraft: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var matchingSummary: String {
        let word = options.matchCase ? "\"Vote\"" : "\"vote\""
        let caseNote = options.matchCase ? "only that exact capitalization" : "any capitalization"
        let accentNote = options.matchAccents ? "\"café\" ≠ \"cafe\"" : "\"café\" = \"cafe\""
        let wordNote = options.wholeWords ? "not inside \"devoted\"" : "also inside \"devoted\""
        return "\(word) matches \(caseNote), \(wordNote). \(accentNote)."
    }

    private func add() {
        let keyword = trimmedDraft
        guard !keyword.isEmpty, !keywords.contains(keyword) else { return }
        keywords.append(keyword)
        KeywordStore.save(keywords)
        draft = ""
    }
}

struct ActivityView: View {
    @State private var entries: [ActivityEntry] = []
    @State private var confirmClear = false
    @State private var errorMessage: String?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                        Button("Try again", action: reload)
                    }
                } else if entries.isEmpty {
                    Text("No messages processed yet.").foregroundStyle(.secondary)
                }
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(entry.sender).font(.headline)
                            Spacer()
                            Text(entry.verdict == .spam ? "Spam" : "Allowed")
                                .font(.caption.bold())
                                .foregroundStyle(entry.verdict == .spam ? .red : .secondary)
                        }
                        Text(entry.received.formatted(date: .abbreviated, time: .standard))
                            .font(.subheadline).foregroundStyle(.secondary)
                        Text(entry.reason)
                    }
                }
                Section {} footer: {
                    Text("Shows up to \(ActivityLog.maxEntries) recent entries with a \(ActivityLog.retentionDays)-day history. Cleanup runs when Sift opens or processes a message. Activity saves sender, time, verdict, and matched keyword on this iPhone; full message text is never stored. Activity may be incomplete if storage is unavailable.")
                }
            }
            .navigationTitle("Activity")
            .toolbar {
                Button("Clear", role: .destructive) { confirmClear = true }.disabled(entries.isEmpty && errorMessage == nil)
            }
            .confirmationDialog("Delete all activity?", isPresented: $confirmClear) {
                Button("Delete All", role: .destructive, action: clear)
            }
            .refreshable { reload() }
            .onAppear(perform: reload)
            .onChange(of: scenePhase) { _, phase in if phase == .active { reload() } }
        }
    }

    private func reload() {
        do {
            entries = try ActivityLog.load()
            errorMessage = nil
        } catch {
            ActivityLog.report(error)
            errorMessage = "Couldn’t refresh activity. Filtering still works. Unlock your iPhone and try again."
        }
    }

    private func clear() {
        do {
            try ActivityLog.clear()
            entries = []
            errorMessage = nil
            reload()
        } catch {
            ActivityLog.report(error)
            errorMessage = "Couldn’t delete activity. Unlock your iPhone and try again."
        }
    }
}
