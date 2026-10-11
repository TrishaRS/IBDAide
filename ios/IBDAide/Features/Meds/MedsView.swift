import SwiftUI
import SwiftData

/// Screen 5 — FR-8 medication tracking, adherence, refills.
/// Embedded in the Care tab's "Meds" segment.
struct MedsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Medication.name) private var medications: [Medication]
    @Query(sort: \DoseEvent.recordedAt, order: .reverse) private var doses: [DoseEvent]
    @Query(sort: \Appointment.date) private var appointments: [Appointment]

    @State private var showEditor = false
    @State private var editing: Medication?

    private var active: [Medication] { medications.filter(\.active) }

    private var refillSoon: [Medication] {
        active.filter { med in
            if let d = med.refillDate, d.timeIntervalSinceNow < 7 * 86400 { return true }
            if let pills = med.pillsRemaining, pills <= med.scheduleTimes.count * 7, !med.scheduleTimes.isEmpty { return true }
            return false
        }
    }

    private var adherence: Int? {
        Analytics.adherencePercent(medications: medications, doses: doses,
                                   from: Calendar.current.date(byAdding: .day, value: -30, to: Date())!,
                                   to: Date())
    }

    var body: some View {
        List {
            if !refillSoon.isEmpty {
                Section {
                    ForEach(refillSoon) { med in
                        Label {
                            Text("Refill soon — \(med.name)").font(.subheadline.bold())
                                .foregroundStyle(Theme.amberText)
                        } icon: {
                            Image(systemName: "bell.badge.fill").foregroundStyle(Theme.amberText)
                        }
                    }
                }
            }

            Section("Today") {
                if todayDoses.isEmpty {
                    Text("No scheduled doses today.").foregroundStyle(.secondary)
                }
                ForEach(todayDoses, id: \.key) { item in
                    doseRow(item.med, minutes: item.minutes, status: item.status)
                }
            }

            Section("All medications") {
                ForEach(medications) { med in
                    Button { editing = med } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(med.name).font(.subheadline.bold())
                                    .foregroundStyle(med.active ? .primary : .secondary)
                                if !med.active { Text("inactive").font(.caption2).foregroundStyle(.secondary) }
                                Spacer()
                                if med.kind == .infusion, let weeks = med.intervalWeeks {
                                    Text("every \(weeks) wks").font(.caption2.bold())
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Theme.accentSoft, in: Capsule())
                                        .foregroundStyle(Theme.accent)
                                }
                            }
                            Text("\(med.dose) · \(med.kind.rawValue)")
                                .font(.caption).foregroundStyle(.secondary)
                            if med.kind == .infusion, let next = nextInfusion() {
                                Text("Next dose: \(next.formatted(date: .abbreviated, time: .omitted)) (linked appointment)")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { idx in
                    for i in idx {
                        NotificationManager.shared.cancelMedReminders(for: medications[i])
                        context.delete(medications[i])
                    }
                    try? context.save()
                }
            }

            Section("Adherence (30 days)") {
                if let adherence {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(adherence)% taken").font(.subheadline.bold())
                            Spacer()
                            Text("\(Analytics.takenStreak(doses: doses))-day streak")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        ProgressView(value: Double(adherence) / 100)
                            .tint(adherence >= 80 ? Theme.chartAccent : .orange)
                    }
                } else {
                    Text("Add a scheduled medication to track adherence.").foregroundStyle(.secondary)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showEditor = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showEditor) { MedicationEditView(medication: nil) }
        .sheet(item: $editing) { med in MedicationEditView(medication: med) }
    }

    // MARK: Today's dose list

    private struct TodayDose { let key: String; let med: Medication; let minutes: Int; let status: DoseStatus? }

    private var todayDoses: [TodayDose] {
        let cal = Calendar.current
        let todayEvents = doses.filter { cal.isDateInToday($0.scheduledAt) }
        return active
            .flatMap { med in med.scheduleTimes.map { (med, $0) } }
            .sorted { $0.1 < $1.1 }
            .map { med, minutes in
                let match = todayEvents.first {
                    $0.medicationID == med.id &&
                    cal.component(.hour, from: $0.scheduledAt) == minutes / 60
                }
                return TodayDose(key: "\(med.id)-\(minutes)", med: med, minutes: minutes, status: match?.status)
            }
    }

    private func doseRow(_ med: Medication, minutes: Int, status: DoseStatus?) -> some View {
        HStack {
            Image(systemName: status == .taken ? "checkmark.circle.fill" : status == .skipped ? "minus.circle.fill" : "circle")
                .foregroundStyle(status == .taken ? Theme.greenText : status == .skipped ? Theme.amberText : Color.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(med.name) \(med.dose)").font(.subheadline)
                Text(String(format: "%d:%02d", minutes / 60, minutes % 60))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if status == nil {
                Button("Taken") { record(med, minutes: minutes, status: .taken) }
                    .buttonStyle(.borderedProminent).controlSize(.small)
                Button("Skip") { record(med, minutes: minutes, status: .skipped) }
                    .buttonStyle(.bordered).controlSize(.small)
            }
        }
    }

    private func record(_ med: Medication, minutes: Int, status: DoseStatus) {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = minutes / 60; comps.minute = minutes % 60
        context.insert(DoseEvent(medicationID: med.id,
                                 scheduledAt: Calendar.current.date(from: comps) ?? Date(),
                                 status: status))
        if status == .taken, let remaining = med.pillsRemaining, remaining > 0 {
            med.pillsRemaining = remaining - 1
        }
        try? context.save()
    }

    private func nextInfusion() -> Date? {
        appointments.first { $0.type == .infusion && $0.date >= Date() }?.date
    }
}
