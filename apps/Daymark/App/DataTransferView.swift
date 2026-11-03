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
            do {
                let url = try result.get()
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                pendingImport = try ArchiveFile.decode(data)
            } catch {
                report(error, title: "Couldn’t import backup", unchanged: true)
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
