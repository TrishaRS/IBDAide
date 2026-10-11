import SwiftUI
import SwiftData

/// FR-1: full symptom log — every field optional, completable in under 60 seconds,
/// backdatable.
struct SymptomLogView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var painOn = false
    @State private var pain = 0.0
    @State private var wellbeingOn = false
    @State private var wellbeing = 0
    @State private var fatigueOn = false
    @State private var fatigue = 1
    @State private var nausea = false
    @State private var jointPain = false
    @State private var skinIssues = false
    @State private var eyeIssues = false
    @State private var mouthUlcers = false
    @State private var weightOn = false
    @State private var weight = ""
    @State private var sleepOn = false
    @State private var sleep = 7.0
    @State private var mood = 2
    @State private var moodOn = false
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Date", selection: $date, in: ...Date())
                }
                Section("How do you feel?") {
                    Toggle("Abdominal pain", isOn: $painOn.animation())
                    if painOn {
                        VStack(alignment: .leading) {
                            Slider(value: $pain, in: 0...10, step: 1)
                            Text("Pain: \(Int(pain)) / 10").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Toggle("General well-being", isOn: $wellbeingOn.animation())
                    if wellbeingOn {
                        Picker("Well-being", selection: $wellbeing) {
                            Text("Very well").tag(0); Text("Slightly below par").tag(1)
                            Text("Poor").tag(2); Text("Very poor").tag(3); Text("Terrible").tag(4)
                        }
                    }
                    Toggle("Fatigue", isOn: $fatigueOn.animation())
                    if fatigueOn {
                        Picker("Fatigue level", selection: $fatigue) {
                            Text("Mild").tag(1); Text("Moderate").tag(2); Text("Severe").tag(3)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                Section("Other symptoms") {
                    Toggle("Nausea", isOn: $nausea)
                    Toggle("Joint pain", isOn: $jointPain)
                    Toggle("Skin issues", isOn: $skinIssues)
                    Toggle("Eye irritation", isOn: $eyeIssues)
                    Toggle("Mouth ulcers", isOn: $mouthUlcers)
                }
                Section("Measurements (optional)") {
                    Toggle("Weight", isOn: $weightOn.animation())
                    if weightOn {
                        TextField("Weight (lbs)", text: $weight).keyboardType(.decimalPad)
                    }
                    Toggle("Sleep", isOn: $sleepOn.animation())
                    if sleepOn {
                        Stepper("Sleep: \(sleep, specifier: "%.1f") h", value: $sleep, in: 0...14, step: 0.5)
                    }
                    Toggle("Mood", isOn: $moodOn.animation())
                    if moodOn {
                        Picker("Mood", selection: $mood) {
                            Text("😞").tag(0); Text("🙁").tag(1); Text("😐").tag(2); Text("🙂").tag(3); Text("😀").tag(4)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                Section("Notes") {
                    TextField("Anything else…", text: $notes, axis: .vertical).lineLimit(3...5)
                }
            }
            .navigationTitle("Log symptoms")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
        }
    }

    private func save() {
        let entry = SymptomEntry(date: date)
        entry.abdominalPain = painOn ? Int(pain) : nil
        entry.wellbeing = wellbeingOn ? wellbeing : nil
        entry.fatigue = fatigueOn ? fatigue : nil
        entry.nausea = nausea
        entry.jointPain = jointPain
        entry.skinIssues = skinIssues
        entry.eyeIssues = eyeIssues
        entry.mouthUlcers = mouthUlcers
        entry.weightLbs = weightOn ? Double(weight) : nil
        entry.sleepHours = sleepOn ? sleep : nil
        entry.mood = moodOn ? mood : nil
        entry.notes = notes
        context.insert(entry)
        try? context.save()
        dismiss()
    }
}
