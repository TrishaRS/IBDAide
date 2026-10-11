import SwiftUI
import SwiftData

/// FR-7: create/edit an appointment, reminders, recurring infusions, prep checklist.
struct AppointmentEditView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Provider.name) private var providers: [Provider]

    let appointment: Appointment?

    @State private var type: AppointmentType = .officeVisit
    @State private var date = Date().addingTimeInterval(86400)
    @State private var providerID: UUID?
    @State private var locationNote = ""
    @State private var isRecurring = false
    @State private var recurringWeeks = 8
    @State private var remind1w = true
    @State private var remind1d = true
    @State private var remind2h = true
    @State private var preVisitNotes = ""
    @State private var postVisitNotes = ""
    @State private var prepDone: Set<String> = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Appointment") {
                    Picker("Type", selection: $type) {
                        ForEach(AppointmentType.allCases) { t in Text(t.rawValue).tag(t) }
                    }
                    DatePicker("When", selection: $date)
                    Picker("Provider / facility", selection: $providerID) {
                        Text("None").tag(UUID?.none)
                        ForEach(providers) { p in Text(p.name).tag(UUID?.some(p.id)) }
                    }
                    TextField("Location note (room, address…)", text: $locationNote)
                }

                if type == .infusion {
                    Section("Recurring infusion") {
                        Toggle("Repeats", isOn: $isRecurring)
                        if isRecurring {
                            Stepper("Every \(recurringWeeks) weeks", value: $recurringWeeks, in: 1...16)
                        }
                    }
                }

                Section("Reminders") {
                    Toggle("1 week before", isOn: $remind1w)
                    Toggle("1 day before", isOn: $remind1d)
                    Toggle("2 hours before", isOn: $remind2h)
                }

                if type == .procedure {
                    Section("Colonoscopy prep checklist") {
                        ForEach(Appointment.prepChecklist, id: \.self) { item in
                            Button {
                                if prepDone.contains(item) { prepDone.remove(item) } else { prepDone.insert(item) }
                            } label: {
                                HStack {
                                    Image(systemName: prepDone.contains(item) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(prepDone.contains(item) ? .green : .secondary)
                                    Text(item).foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                }

                Section("Notes") {
                    TextField("Before the visit…", text: $preVisitNotes, axis: .vertical).lineLimit(2...4)
                    TextField("After the visit…", text: $postVisitNotes, axis: .vertical).lineLimit(2...4)
                }
            }
            .navigationTitle(appointment == nil ? "New appointment" : "Edit appointment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard let a = appointment else { return }
        type = a.type; date = a.date; providerID = a.providerID; locationNote = a.locationNote
        isRecurring = a.recurringWeeks != nil
        recurringWeeks = a.recurringWeeks ?? 8
        remind1w = a.reminderOffsetsHours.contains(168)
        remind1d = a.reminderOffsetsHours.contains(24)
        remind2h = a.reminderOffsetsHours.contains(2)
        preVisitNotes = a.preVisitNotes; postVisitNotes = a.postVisitNotes
        prepDone = Set(a.prepDone)
    }

    private func save() {
        let a = appointment ?? Appointment()
        a.type = type; a.date = date; a.providerID = providerID; a.locationNote = locationNote
        a.recurringWeeks = (type == .infusion && isRecurring) ? recurringWeeks : nil
        var offsets: [Int] = []
        if remind1w { offsets.append(168) }
        if remind1d { offsets.append(24) }
        if remind2h { offsets.append(2) }
        a.reminderOffsetsHours = offsets
        a.preVisitNotes = preVisitNotes; a.postVisitNotes = postVisitNotes
        a.prepDone = Array(prepDone)
        if appointment == nil { context.insert(a) }
        try? context.save()
        NotificationManager.shared.scheduleAppointmentReminders(for: a)

        // Auto-create the next occurrence for recurring infusions once this one passes.
        if let weeks = a.recurringWeeks, a.date < Date() {
            let next = Appointment(type: .infusion, date: Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: a.date)!)
            next.providerID = a.providerID; next.recurringWeeks = weeks
            next.reminderOffsetsHours = a.reminderOffsetsHours
            context.insert(next)
            try? context.save()
            NotificationManager.shared.scheduleAppointmentReminders(for: next)
        }
        dismiss()
    }
}
