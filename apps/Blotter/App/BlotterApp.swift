// Copyright (c) 2026 Michael Droessler
// SPDX-License-Identifier: PolyForm-Noncommercial-1.0.0

import SwiftUI

@main
struct BlotterApp: App {
    @State private var setupDone = (UserDefaults(suiteName: Blotter.appGroup)?.bool(forKey: "setupDone")) ?? false

    var body: some Scene {
        WindowGroup {
            Group {
                if setupDone {
                    KeywordsView()
                } else {
                    SetupView {
                        setupDone = true
                        UserDefaults(suiteName: Blotter.appGroup)?.set(true, forKey: "setupDone")
                    }
                }
            }
        }
    }
}

struct SetupView: View {
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "funnel.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.indigo)
                    .accessibilityHidden(true)
                Text("Set up Blotter")
                    .font(.title.bold())
                    .accessibilityAddTraits(.isHeader)
                VStack(alignment: .leading, spacing: 16) {
                    Text("1. In iPhone Settings, go to Apps → Messages → Text Message Filter and choose Blotter.")
                    Text("2. Add the keywords you want to block. Texts containing them go silently to Junk.")
                    Text("3. Adjust case, accent, and whole-word matching to suit your rules.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Text("Works on SMS/MMS from numbers not in your Contacts. Filtering happens on your iPhone. Blotter doesn’t save messages or a history of keyword matches.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Get started", action: onDone)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                VStack(spacing: 16) {
                    HelpAndPrivacyLinks()
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
    }
}

struct KeywordsView: View {
    @State private var keywords = KeywordStore.load()
    @State private var draft = ""
    @State private var options = KeywordStore.loadOptions()

    var body: some View {
        NavigationStack {
            List {
                Section("Enable Blotter") {
                    Text("In iPhone Settings, go to Apps → Messages → Text Message Filter and choose Blotter.")
                    Text("Adding keywords here doesn’t enable filtering. Check your selection in Settings.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section {
                    HStack {
                        TextField("Add keyword or phrase", text: $draft)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit(add)
                        Button("Add", action: add).disabled(trimmedDraft.isEmpty)
                    }
                } footer: {
                    Text("Texts from unknown senders containing any keyword go silently to Junk. Senders in Contacts and iMessage are never filtered.")
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
                Section("Help & Privacy") {
                    HelpAndPrivacyLinks()
                }
            }
            .navigationTitle("Blotter")
        }
    }

    private var trimmedDraft: String { draft.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var matchingSummary: String {
        let word = "\"vote\""
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

private struct HelpAndPrivacyLinks: View {
    var body: some View {
        Group {
            Link("Help & Support", destination: URL(string: "https://apps.droessmj.com/blotter/support.html")!)
            Link("Privacy Policy", destination: URL(string: "https://apps.droessmj.com/blotter/privacy.html")!)
        }
    }
}
