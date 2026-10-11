import SwiftUI
import SwiftData

/// Screen 1 — Today + quick log (FR-1, NFR-6: quick BM log ≤10 s, ≤2 taps).
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @Query(sort: \SymptomEntry.date, order: .reverse) private var symptoms: [SymptomEntry]
    @Query(sort: \BowelMovementEntry.date, order: .reverse) private var stools: [BowelMovementEntry]
    @Query(sort: \Appointment.date) private var appointments: [Appointment]
    @Query private var medications: [Medication]
    @Query(sort: \DoseEvent.recordedAt, order: .reverse) private var doses: [DoseEvent]
    @Query private var questions: [VisitQuestion]

    @State private var showSymptomLog = false
    @State private var showMealSheet = false
    @State private var bristolPick: Int?
    @State private var bmBlood = false
    @State private var bmUrgency = 0
    @State private var waterToast = false

    private var profile: UserProfile? { profiles.first }

    private var todayScore: (score: Int?, band: ScoreBand, label: String) {
        guard let profile else { return (nil, .unknown, "") }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let snap = DailySnapshot.build(
            symptoms: symptoms.filter { cal.startOfDay(for: $0.date) == today },
            stools: stools.filter { cal.startOfDay(for: $0.date) == today })
        return Scoring.score(for: profile.diagnosis, snapshot: snap)
    }

    private var nextAppointment: Appointment? {
        appointments.first { $0.date >= Date() }
    }

    private var openQuestionCount: Int {
        questions.filter { !$0.asked }.count
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    VStack(spacing: 12) {
                        scoreCard
                        quickLogRow
                        bristolCard
                        if let appt = nextAppointment { appointmentCard(appt) }
                        medsDueCard
                    }
                    .padding(.horizontal)
                }
                fab
            }
            .navigationTitle(greeting)
            .sheet(isPresented: $showSymptomLog) { SymptomLogView() }
            .sheet(isPresented: $showMealSheet) { QuickMealSheet() }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let base = hour < 12 ? "Good morning" : hour < 17 ? "Good afternoon" : "Good evening"
        let name = profile?.name ?? ""
        return name.isEmpty ? base : "\(base), \(name)"
    }

    private var scoreCard: some View {
        let s = todayScore
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Today's score · \(s.label)").font(.subheadline.bold())
                Spacer()
                Text(s.score.map { "\(s.band.rawValue) · \($0)" } ?? "No data yet")
                    .font(.caption.bold())
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Theme.bandColor(s.band).opacity(0.18), in: Capsule())
                    .foregroundStyle(Theme.bandTextColor(s.band))
            }
            Text("For discussion with your care team — not a diagnosis")
                .font(.caption2).foregroundStyle(.secondary)
            SourcesLink()
        }
        .cardStyle()
    }

    private var quickLogRow: some View {
        HStack(spacing: 10) {
            Button {
                context.insert(HydrationEntry())
                try? context.save()
                waterToast = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { waterToast = false }
            } label: {
                Label(waterToast ? "Logged!" : "Water", systemImage: "drop.fill")
                    .frame(maxWidth: .infinity)
            }
            Button { showMealSheet = true } label: {
                Label("Meal", systemImage: "fork.knife").frame(maxWidth: .infinity)
            }
            Button { showSymptomLog = true } label: {
                Label("Symptoms", systemImage: "list.clipboard").frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.bordered)
    }

    private var bristolCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bristol quick-tap").font(.subheadline.bold())
            HStack(spacing: 6) {
                ForEach(1...7, id: \.self) { n in
                    Button {
                        bristolPick = n
                    } label: {
                        Text("\(n)")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(bristolPick == n ? Theme.accent : Color(.tertiarySystemFill),
                                        in: RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(bristolPick == n ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            if bristolPick != nil {
                HStack {
                    Toggle("Blood", isOn: $bmBlood).toggleStyle(.button).font(.caption)
                    Picker("Urgency", selection: $bmUrgency) {
                        Text("No urgency").tag(0); Text("Hurry").tag(1)
                        Text("Immediately").tag(2); Text("Accident").tag(3)
                    }
                    .pickerStyle(.menu).font(.caption)
                    Spacer()
                    Button("Save") {
                        let bm = BowelMovementEntry(bristol: bristolPick ?? 4, blood: bmBlood, urgency: bmUrgency)
                        let hour = Calendar.current.component(.hour, from: Date())
                        bm.nighttime = hour < 6 || hour >= 22
                        context.insert(bm)
                        try? context.save()
                        bristolPick = nil; bmBlood = false; bmUrgency = 0
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .cardStyle()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Bristol stool chart quick log")
    }

    private func appointmentCard(_ appt: Appointment) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Next: \(appt.type.rawValue)").font(.subheadline.bold())
                Text(appt.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if openQuestionCount > 0 {
                Text("\(openQuestionCount) questions")
                    .font(.caption.bold())
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Theme.accentSoft, in: Capsule())
                    .foregroundStyle(Theme.accent)
            }
        }
        .cardStyle()
    }

    private var medsDueCard: some View {
        let cal = Calendar.current
        let now = Date()
        let nowMinutes = cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now)
        let takenToday = Set(doses
            .filter { cal.isDateInToday($0.scheduledAt) }
            .map { "\($0.medicationID)-\(cal.component(.hour, from: $0.scheduledAt) * 60)" })

        let due: [(Medication, Int)] = medications
            .filter(\.active)
            .flatMap { med in med.scheduleTimes.map { (med, $0) } }
            .filter { $0.1 <= nowMinutes + 60 }
            .filter { !takenToday.contains("\($0.0.id)-\(($0.1 / 60) * 60)") }
            .sorted { $0.1 < $1.1 }

        return Group {
            if let next = due.first {
                let med = next.0, minutes = next.1
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Meds due").font(.subheadline.bold())
                        Text("\(med.name) \(med.dose) · \(String(format: "%d:%02d", minutes / 60, minutes % 60))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Taken") { record(med, minutes: minutes, status: .taken) }
                        .buttonStyle(.borderedProminent).controlSize(.small)
                    Button("Skip") { record(med, minutes: minutes, status: .skipped) }
                        .buttonStyle(.bordered).controlSize(.small)
                }
                .cardStyle()
            }
        }
    }

    private func record(_ med: Medication, minutes: Int, status: DoseStatus) {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = minutes / 60; comps.minute = minutes % 60
        let scheduled = Calendar.current.date(from: comps) ?? Date()
        context.insert(DoseEvent(medicationID: med.id, scheduledAt: scheduled, status: status))
        if status == .taken, let remaining = med.pillsRemaining, remaining > 0 {
            med.pillsRemaining = remaining - 1
        }
        try? context.save()
    }

    private var fab: some View {
        Button { showSymptomLog = true } label: {
            Image(systemName: "plus")
                .font(.title2.bold())
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Theme.accent, in: Circle())
                .shadow(radius: 4, y: 2)
        }
        .padding(20)
        .accessibilityLabel("Log symptoms")
    }
}

/// Minimal meal logger (FR-3) — free text + flags; scans arrive via the Scan tab.
struct QuickMealSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var triggers: [TriggerFood]

    @State private var name = ""
    @State private var caffeine = false
    @State private var alcohol = false
    @State private var markTrigger = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("What did you eat?", text: $name)
                Toggle("Contains caffeine", isOn: $caffeine)
                Toggle("Contains alcohol", isOn: $alcohol)
                Toggle("Mark as a personal trigger food", isOn: $markTrigger)
            }
            .navigationTitle("Log meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let entry = FoodEntry(name: name)
                        entry.caffeine = caffeine; entry.alcohol = alcohol
                        context.insert(entry)
                        if markTrigger, !triggers.contains(where: { $0.name.lowercased() == name.lowercased() }) {
                            context.insert(TriggerFood(name: name))
                        }
                        try? context.save()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
