import SwiftUI
import UniformTypeIdentifiers
import HabitKit

struct DaymarkBackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    let data: Data

    init(archive: HabitArchive) throws {
        data = try ArchiveFile.encode(archive)
    }

    init(configuration: ReadConfiguration) throws {
        guard let contents = configuration.file.regularFileContents else { throw ArchiveValidationError.invalidData }
        _ = try ArchiveFile.decode(contents)
        data = contents
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct DataTransferView: View {
    @Environment(HabitStore.self) private var store
    @State private var exportDocument: DaymarkBackupDocument?
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var isConfirmingImport = false
    @State private var pendingImport: HabitArchive?
    @State private var notice: TransferNotice?
    @State private var legacyBackup: LegacyBackupRequest?
    @State private var readingBackup = false

    private var backupFilename: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return "Day-in-Ink-Backup-\(formatter.string(from: Date()))"
    }

    var body: some View {
        List {
            Section {
                Button("Export backup", systemImage: "square.and.arrow.up", action: exportBackup)
                    .disabled(!store.ready)
                    .accessibilityIdentifier("export-backup")
            } header: {
                Text("Export")
            } footer: {
                Text("Save all habits and recorded history, including archived habits, as a JSON file in Files. Keep this file to restore your data or move it to another iPhone.")
            }

            Section {
                Button("Import backup", systemImage: "square.and.arrow.down") { isImporting = true }
                    .accessibilityIdentifier("import-backup")
                    .disabled(readingBackup)
                if readingBackup { ProgressView("Reading backup…") }
            } header: {
                Text("Import")
            } footer: {
                Text("Choose a Day in Ink JSON backup. Backups from Daymark also work. You’ll review its contents before replacing all current habits and history. Export your current data first if you want to keep a copy.")
            }

            if let imported = pendingImport {
                Section("Review backup") {
                    Text("\(imported.habits.count) habits, including \(imported.habits.filter(\.isArchived).count) archived, and \(imported.entries.count) recorded check-ins.")
                    Button("Replace current data", role: .destructive) { isConfirmingImport = true }
                        .accessibilityIdentifier("confirm-import")
                    Button("Cancel import") { pendingImport = nil }
                }
            }

            Section("Your backup") {
                Text("Backup files contain your habit names and history. They aren’t encrypted by Day in Ink. Choose a storage location you trust; copies you save outside the app are managed separately.")
            }
        }
        .navigationTitle("Export and import")
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(isPresented: $isExporting, document: exportDocument, contentType: .json,
                      defaultFilename: backupFilename) { result in
            switch result {
            case .success:
                notice = TransferNotice(title: "Backup exported", message: "Your habits and history have been saved to the location you chose.")
            case .failure(let error): report(error, title: "Couldn’t export backup")
            }
            exportDocument = nil
        }
        // Some Files providers classify JSON backups as generic data. Validate the contents below.
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json, .data]) { result in
            switch result {
            case .success(let url): importBackup(from: url)
            case .failure(let error): report(error, title: "Couldn’t import backup", unchanged: true)
            }
        }
        .confirmationDialog("Replace all Day in Ink data?", isPresented: $isConfirmingImport,
                            titleVisibility: .visible, presenting: pendingImport) { imported in
            Button("Replace all data", role: .destructive) { restore(imported) }
            Button("Cancel", role: .cancel) { pendingImport = nil }
        } message: { imported in
            let archived = imported.habits.filter(\.isArchived).count
            Text("This backup contains \(imported.habits.count) habits (\(archived) archived) and \(imported.entries.count) recorded check-ins. It will replace your current habits and history. This cannot be undone.")
        }
        .alert(item: $notice) { notice in
            Alert(title: Text(notice.title), message: Text(notice.message), dismissButton: .default(Text("OK")))
        }
        .sheet(item: $legacyBackup) { request in
            LegacyCalendarPicker(title: "Import an older backup", onChoose: { calendar in
                legacyBackup = nil
                importBackup(from: request.url, legacyCalendar: calendar)
            }, onCancel: { legacyBackup = nil })
        }
    }

    private func importBackup(from url: URL, legacyCalendar: Calendar? = nil) {
        readingBackup = true
        pendingImport = nil
        Task {
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
                readingBackup = false
            }
            do {
                pendingImport = try await Task.detached(priority: .userInitiated) {
                    try ArchiveFile.read(from: url, legacyCalendar: legacyCalendar)
                }.value
            } catch ArchiveValidationError.legacyCalendarRequired {
                legacyBackup = LegacyBackupRequest(url: url)
            } catch {
                report(error, title: "Couldn’t import backup", unchanged: true)
            }
        }
    }

    private func exportBackup() {
        do {
            exportDocument = try DaymarkBackupDocument(archive: store.archive)
            isExporting = true
        } catch {
            report(error, title: "Couldn’t export backup")
        }
    }

    private func restore(_ imported: HabitArchive) {
        pendingImport = nil
        do {
            try store.restore(imported)
            notice = TransferNotice(title: "Backup imported", message: "Your habits and history have been restored.")
        } catch {
            report(error, title: "Couldn’t import backup", unchanged: true)
        }
    }

    private func report(_ error: Error, title: String, unchanged: Bool = false) {
        if let error = error as? CocoaError, error.code == .userCancelled { return }
        pendingImport = nil
        notice = TransferNotice(title: title,
                                message: (unchanged ? "Your current data hasn’t changed. " : "") + error.localizedDescription)
    }
}

private struct TransferNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

private struct LegacyBackupRequest: Identifiable {
    let id = UUID()
    let url: URL
}

/// Version 1 saved day components without a calendar identifier; never silently guess one.
struct LegacyCalendarPicker: View {
    let title: String
    let onChoose: (Calendar) -> Void
    var onCancel: (() -> Void)?
    @State private var identifier = Calendar.current.identifier

    private let calendars: [(Calendar.Identifier, String)] = [
        (.gregorian, "Gregorian"), (.buddhist, "Buddhist"), (.chinese, "Chinese"),
        (.coptic, "Coptic"), (.ethiopicAmeteMihret, "Ethiopic (Amete Mihret)"),
        (.ethiopicAmeteAlem, "Ethiopic (Amete Alem)"), (.hebrew, "Hebrew"),
        (.iso8601, "ISO 8601"), (.indian, "Indian"), (.islamic, "Islamic"),
        (.islamicCivil, "Islamic Civil"), (.islamicTabular, "Islamic Tabular"),
        (.islamicUmmAlQura, "Islamic Umm al-Qura"), (.japanese, "Japanese"),
        (.persian, "Persian"), (.republicOfChina, "Republic of China")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Older versions saved day numbers without identifying their calendar. Choose the iPhone calendar used when this history was recorded—not a different calendar you selected later.")
                    Picker("Original calendar", selection: $identifier) {
                        ForEach(calendars, id: \.0) { calendar in
                            Text(calendar.1).tag(calendar.0)
                        }
                    }
                    .accessibilityIdentifier("legacy-calendar")
                    Text("If you never changed your iPhone’s calendar, use the selection shown. Your existing data is kept if conversion fails.")
                    Text("Some older calendars require era or leap-month information that the old file did not store. If conversion is unavailable, keep the original file and contact support instead of guessing.")
                    Button("Use this calendar") {
                        var calendar = Calendar(identifier: identifier)
                        calendar.timeZone = .current
                        onChoose(calendar)
                    }
                    .accessibilityIdentifier("confirm-legacy-calendar")
                }
                Section("Support and privacy") {
                    Link("Help & Support", destination: URL(string: "https://apps.droessmj.com/day-in-ink/support.html")!)
                    Link("Privacy Policy", destination: URL(string: "https://apps.droessmj.com/day-in-ink/privacy.html")!)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let onCancel {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) }
                }
            }
        }
    }
}
