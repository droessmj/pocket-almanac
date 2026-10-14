import SwiftUI

@main
struct SiftApp: App {
    init() { ActivityLog.clearIfReinstalled() }

    var body: some Scene {
        WindowGroup {
            TabView {
                Tab("Keywords", systemImage: "text.badge.xmark") { KeywordsView() }
                Tab("Activity", systemImage: "list.bullet.rectangle") { ActivityView() }
            }
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
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            List {
                if entries.isEmpty {
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
                    VStack(alignment: .leading) {
                        Text("Kept on this iPhone only, for \(ActivityLog.retentionDays) days (max \(ActivityLog.maxEntries)). Message text is never stored.")
                        if let limit = entries.first?.filterMemoryLimitMB {
                            Text(String(format: "Filter memory limit: %.0f MB", limit))
                        }
                    }
                }
            }
            .navigationTitle("Activity")
            .toolbar {
                Button("Clear", role: .destructive) { confirmClear = true }.disabled(entries.isEmpty)
            }
            .confirmationDialog("Delete all activity?", isPresented: $confirmClear) {
                Button("Delete All", role: .destructive) { ActivityLog.clear(); reload() }
            }
            .refreshable { reload() }
            .onAppear(perform: reload)
            .onChange(of: scenePhase) { _, phase in if phase == .active { reload() } }
        }
    }

    private func reload() { entries = ActivityLog.load() }
}
