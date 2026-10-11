import SwiftUI
import SwiftData

/// Settings: app lock (FR-13), flare mode, triggers, backup & restore (FR-14b), privacy.
struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var lock: AppLockManager
    @Query private var profiles: [UserProfile]
    @Query(sort: \TriggerFood.name) private var triggers: [TriggerFood]

    @State private var newTrigger = ""

    // Export
    @State private var showExportPassphrase = false
    @State private var exportPassphrase = ""
    @State private var exportDoc: BackupDocument?
    @State private var showExporter = false

    // Import
    @State private var showImporter = false
    @State private var importData: Data?
    @State private var showImportPassphrase = false
    @State private var importPassphrase = ""

    @State private var statusMessage: String?
    @State private var showDeleteConfirm = false

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        Form {
            Section("Profile") {
                if let profile {
                    TextField("Name", text: Binding(get: { profile.name }, set: { profile.name = $0; try? context.save() }))
                    Picker("Diagnosis", selection: Binding(get: { profile.diagnosis }, set: { profile.diagnosis = $0; try? context.save() })) {
                        ForEach(Diagnosis.allCases) { d in Text(d.rawValue).tag(d) }
                    }
                    Toggle("Flare mode (stricter food rules)", isOn: Binding(get: { profile.flareMode }, set: { profile.flareMode = $0; try? context.save() }))
                }
            }

            Section("Security") {
                Toggle("Require \(lock.biometryLabel) to open", isOn: $lock.lockEnabled)
                Picker("Auto-lock delay", selection: $lock.graceSeconds) {
                    Text("Immediately").tag(0)
                    Text("After 1 minute").tag(60)
                    Text("After 5 minutes").tag(300)
                }
                Text("All data is stored only on this phone and encrypted at rest by iOS Data Protection.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Personal trigger foods") {
                ForEach(triggers) { t in
                    HStack {
                        Text(t.name)
                        Spacer()
                        Text(t.origin == "user" ? "" : "suggested").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .onDelete { idx in
                    for i in idx { context.delete(triggers[i]) }
                    try? context.save()
                }
                HStack {
                    TextField("Add trigger food…", text: $newTrigger)
                    Button {
                        context.insert(TriggerFood(name: newTrigger))
                        newTrigger = ""
                        try? context.save()
                    } label: { Image(systemName: "plus.circle.fill") }
                    .disabled(newTrigger.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section("Backup & device migration") {
                Text("Your data already survives phone upgrades through your encrypted iCloud or computer backup. You can also make a portable encrypted backup file:")
                    .font(.caption).foregroundStyle(.secondary)
                Button {
                    showExportPassphrase = true
                } label: {
                    Label("Export encrypted backup…", systemImage: "square.and.arrow.up")
                }
                Button {
                    showImporter = true
                } label: {
                    Label("Restore from backup…", systemImage: "square.and.arrow.down")
                }
                if let statusMessage {
                    Text(statusMessage).font(.caption).foregroundStyle(.secondary)
                }
            }

            Section("About & privacy") {
                LabeledContent("Version", value: "1.0")
                Text("Free. No ads. No accounts. No analytics. Your health data never leaves this phone — the only network requests are barcode lookups (barcode digits only), news feeds, and map search.")
                    .font(.caption).foregroundStyle(.secondary)
                Text(disclaimerText).font(.caption2).foregroundStyle(.secondary)
            }

            Section {
                Button(role: .destructive) { showDeleteConfirm = true } label: {
                    Label("Delete all data", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Settings")
        // Export passphrase prompt
        .alert("Choose a backup passphrase", isPresented: $showExportPassphrase) {
            SecureField("Passphrase", text: $exportPassphrase)
            Button("Export") { runExport() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You'll need this passphrase to restore the backup. It cannot be recovered.")
        }
        .fileExporter(isPresented: $showExporter, document: exportDoc, contentType: .data,
                      defaultFilename: "IBD-Aide-Backup.ibdaide") { result in
            statusMessage = (try? result.get()) != nil ? "Backup exported." : "Export cancelled."
        }
        // Import flow
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.data, .item]) { result in
            guard let url = try? result.get() else { return }
            let secured = url.startAccessingSecurityScopedResource()
            defer { if secured { url.stopAccessingSecurityScopedResource() } }
            importData = try? Data(contentsOf: url)
            if importData != nil { showImportPassphrase = true }
            else { statusMessage = "Couldn't read that file." }
        }
        .alert("Backup passphrase", isPresented: $showImportPassphrase) {
            SecureField("Passphrase", text: $importPassphrase)
            Button("Restore", role: .destructive) { runImport() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Restoring replaces ALL current data in IBD Aide.")
        }
        .confirmationDialog("Delete all data? This cannot be undone.",
                            isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) { deleteAll() }
        }
    }

    private func runExport() {
        defer { exportPassphrase = "" }
        guard exportPassphrase.count >= 6 else { statusMessage = "Use a passphrase of at least 6 characters."; return }
        do {
            let env = try ExportManager.buildEnvelope(context: context)
            let data = try ExportManager.encrypt(env, passphrase: exportPassphrase)
            exportDoc = BackupDocument(data: data)
            showExporter = true
        } catch {
            statusMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    private func runImport() {
        defer { importPassphrase = ""; importData = nil }
        guard let data = importData else { return }
        do {
            let env = try ExportManager.decrypt(data, passphrase: importPassphrase)
            try ExportManager.apply(env, context: context)
            statusMessage = "Backup restored."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func deleteAll() {
        try? context.delete(model: UserProfile.self)
        try? context.delete(model: SymptomEntry.self)
        try? context.delete(model: BowelMovementEntry.self)
        try? context.delete(model: FoodEntry.self)
        try? context.delete(model: TriggerFood.self)
        try? context.delete(model: HydrationEntry.self)
        try? context.delete(model: Medication.self)
        try? context.delete(model: DoseEvent.self)
        try? context.delete(model: Provider.self)
        try? context.delete(model: Appointment.self)
        try? context.delete(model: VisitQuestion.self)
        try? context.delete(model: QoLCheckin.self)
        try? context.delete(model: ScannedProduct.self)
        try? context.delete(model: NewsItem.self)
        try? context.delete(model: NutritionistRule.self)
        try? context.save()
    }
}
