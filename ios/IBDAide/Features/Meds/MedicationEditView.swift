import SwiftUI
import SwiftData

/// FR-8: create/edit a medication with schedule, refill tracking, reminders.
struct MedicationEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let medication: Medication?

    @State private var name = ""
    @State private var dose = ""
    @State private var kind: MedicationKind = .oral
    @State private var prescriber = ""
    @State private var times: [Date] = []
    @State private var intervalWeeks = 8
    @State private var trackPills = false
    @State private var pillsRemaining = 30
    @State private var trackRefill = false
    @State private var refillDate = Date().addingTimeInterval(30 * 86400)
    @State private var active = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Medication") {
                    TextField("Name", text: $name)
                    TextField("Dose (e.g. 800 mg)", text: $dose)
                    Picker("Type", selection: $kind) {
                        ForEach(MedicationKind.allCases) { k in Text(k.rawValue).tag(k) }
                    }
                    TextField("Prescriber", text: $prescriber)
                    Toggle("Active", isOn: $active)
                }

                if kind == .infusion {
                    Section("Infusion schedule") {
                        Stepper("Every \(intervalWeeks) weeks", value: $intervalWeeks, in: 1...16)
                        Text("Create the matching IV appointment in Care ▸ Appointments to get reminders and prep tracking.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Section("Daily reminder times") {
                        ForEach(times.indices, id: \.self) { i in
                            DatePicker("Dose \(i + 1)", selection: $times[i], displayedComponents: .hourAndMinute)
                        }
                        .onDelete { times.remove(atOffsets: $0) }
                        Button {
                            times.append(Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!)
                        } label: {
                            Label("Add time", systemImage: "plus.circle")
                        }
                    }
                    Section("Refills") {
                        Toggle("Track pills remaining", isOn: $trackPills.animation())
                        if trackPills {
                            Stepper("\(pillsRemaining) pills left", value: $pillsRemaining, in: 0...500)
                        }
                        Toggle("Refill date reminder", isOn: $trackRefill.animation())
                        if trackRefill {
                            DatePicker("Refill due", selection: $refillDate, displayedComponents: .date)
                        }
                    }
                }
            }
            .navigationTitle(medication == nil ? "New medication" : "Edit medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let m = medication else { return }
        name = m.name; dose = m.dose; kind = m.kind; prescriber = m.prescriber; active = m.active
        intervalWeeks = m.intervalWeeks ?? 8
        times = m.scheduleTimes.compactMap {
            Calendar.current.date(bySettingHour: $0 / 60, minute: $0 % 60, second: 0, of: Date())
        }
        if let pills = m.pillsRemaining { trackPills = true; pillsRemaining = pills }
        if let refill = m.refillDate { trackRefill = true; refillDate = refill }
    }

    private func save() {
        let m = medication ?? Medication()
        m.name = name; m.dose = dose; m.kind = kind; m.prescriber = prescriber; m.active = active
        m.intervalWeeks = kind == .infusion ? intervalWeeks : nil
        m.scheduleTimes = kind == .infusion ? [] : times.map {
            Calendar.current.component(.hour, from: $0) * 60 + Calendar.current.component(.minute, from: $0)
        }.sorted()
        m.pillsRemaining = trackPills ? pillsRemaining : nil
        m.refillDate = trackRefill ? refillDate : nil
        if medication == nil { context.insert(m) }
        try? context.save()
        NotificationManager.shared.scheduleMedReminders(for: m)
        NotificationManager.shared.scheduleRefillAlert(for: m)
        dismiss()
    }
}
