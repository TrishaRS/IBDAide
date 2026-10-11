import SwiftUI
import SwiftData

/// Screen 6 — FR-9 doctor report: build PDF on device, share via the user's own apps.
struct ReportView: View {
    @Query private var profiles: [UserProfile]
    @Query(sort: \SymptomEntry.date) private var symptoms: [SymptomEntry]
    @Query(sort: \BowelMovementEntry.date) private var stools: [BowelMovementEntry]
    @Query private var medications: [Medication]
    @Query private var doses: [DoseEvent]
    @Query private var triggers: [TriggerFood]
    @Query(sort: \VisitQuestion.createdAt) private var questions: [VisitQuestion]
    @Query(sort: \QoLCheckin.date) private var qol: [QoLCheckin]

    @State private var rangeDays = 30
    @State private var includeQoL = true
    @State private var includeQuestions = true
    @State private var includeTriggers = true
    @State private var pdfURL: URL?

    var body: some View {
        Form {
            Section("Period") {
                Picker("Range", selection: $rangeDays) {
                    Text("2 weeks").tag(14); Text("30 days").tag(30); Text("90 days").tag(90)
                }
                .pickerStyle(.segmented)
            }
            Section("Include") {
                Label("Symptom summary & score trend", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.secondary)
                Label("Medication adherence", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.secondary)
                Toggle("Food triggers", isOn: $includeTriggers)
                Toggle("Questions for this visit", isOn: $includeQuestions)
                Toggle("Quality-of-life check-ins", isOn: $includeQoL)
            }
            Section {
                Button {
                    generate()
                } label: {
                    Label("Generate PDF", systemImage: "doc.badge.gearshape")
                        .frame(maxWidth: .infinity)
                }
                if let pdfURL {
                    ShareLink(item: pdfURL) {
                        Label("Share PDF…", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            Section {
                Text("Opens your share sheet (Mail, Messages…). IBD Aide never sends your data itself.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Doctor report")
    }

    private func generate() {
        let profile = profiles.first
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -rangeDays, to: end)!

        let diagnosis = profile?.diagnosis ?? .crohns
        let scores = Analytics.dailyScores(diagnosis: diagnosis, symptoms: symptoms,
                                           stools: stools, from: start, to: end)
        let periodStools = stools.filter { $0.date >= start }
        let bloodDays = Set(periodStools.filter(\.blood).map { Calendar.current.startOfDay(for: $0.date) }).count
        let pains = symptoms.filter { $0.date >= start }.compactMap(\.abdominalPain)

        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "MMM d"
        let scoreLines = scores.map { point in
            "\(dayFormatter.string(from: point.day)):  \(point.score)  (\(Scoring.band(for: diagnosis, score: point.score).rawValue))"
        }

        let data = ReportData(
            patientName: profile?.name ?? "",
            diagnosis: diagnosis.rawValue,
            scoreLabel: diagnosis == .crohns ? "Modified HBI" : diagnosis == .ulcerativeColitis ? "Modified SCCAI" : "Symptom burden",
            startDate: start, endDate: end,
            dailyScores: scores.map { ($0.day, $0.score) },
            scoreLines: scoreLines,
            totalBMs: periodStools.count,
            bloodDays: bloodDays,
            avgPain: pains.isEmpty ? nil : Double(pains.reduce(0, +)) / Double(pains.count),
            adherencePercent: Analytics.adherencePercent(medications: medications, doses: doses, from: start, to: end),
            triggers: includeTriggers ? triggers.map(\.name) : [],
            questions: includeQuestions ? questions.filter { !$0.asked }.map(\.text) : [],
            qolTotals: qol.map { ($0.date, $0.total) },
            includeQoL: includeQoL
        )

        let pdf = PDFReportBuilder.makePDF(data)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("IBD-Aide-Report-\(Int(end.timeIntervalSince1970)).pdf")
        try? pdf.write(to: url, options: [.completeFileProtection])
        pdfURL = url
    }
}
