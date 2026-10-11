import SwiftUI
import SwiftData
import Charts

/// Screen 2 — FR-2 insights & flare watch, FR-12 QoL trend.
struct TrendsView: View {
    @Query private var profiles: [UserProfile]
    @Query(sort: \SymptomEntry.date) private var symptoms: [SymptomEntry]
    @Query(sort: \BowelMovementEntry.date) private var stools: [BowelMovementEntry]
    @Query(sort: \FoodEntry.date) private var foods: [FoodEntry]
    @Query(sort: \QoLCheckin.date) private var qol: [QoLCheckin]

    @State private var rangeDays = 30

    private var profile: UserProfile? { profiles.first }

    private var startDate: Date {
        Calendar.current.date(byAdding: .day, value: -rangeDays, to: Date())!
    }

    private var scores: [(day: Date, score: Int)] {
        guard let profile else { return [] }
        return Analytics.dailyScores(diagnosis: profile.diagnosis, symptoms: symptoms,
                                     stools: stools, from: startDate, to: Date())
    }

    private var flare: Analytics.FlareStatus {
        guard let profile else { return .init(possibleFlare: false, baseline: 0, elevatedDays: 0) }
        let all = Analytics.dailyScores(diagnosis: profile.diagnosis, symptoms: symptoms,
                                        stools: stools,
                                        from: Calendar.current.date(byAdding: .day, value: -40, to: Date())!,
                                        to: Date())
        return Analytics.flareStatus(scores: all)
    }

    private var correlations: [Analytics.TriggerCorrelation] {
        Analytics.triggerCorrelations(foods: foods, scores: scores, baseline: flare.baseline)
    }

    private var bmPerDay: [(day: Date, count: Int)] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: stools.filter { $0.date >= startDate },
                                 by: { cal.startOfDay(for: $0.date) })
        return grouped.map { ($0.key, $0.value.count) }.sorted { $0.0 < $1.0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    Picker("Range", selection: $rangeDays) {
                        Text("Week").tag(7); Text("Month").tag(30); Text("Year").tag(365)
                    }
                    .pickerStyle(.segmented)

                    if flare.possibleFlare { flareBanner }

                    scoreChart
                    bmChart
                    triggerCard
                    qolCard
                    SourcesLink()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal)
            }
            .navigationTitle("Trends")
        }
    }

    private var flareBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.amberText)
            VStack(alignment: .leading, spacing: 2) {
                Text("Possible flare pattern").font(.subheadline.bold()).foregroundStyle(Theme.amberText)
                Text("Your score has been above your usual baseline on \(flare.elevatedDays) of the last 7 logged days. Consider contacting your care team.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .cardStyle()
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(.orange.opacity(0.5)))
    }

    private var scoreChart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(scoreLabel) score").font(.subheadline.bold())
            if scores.isEmpty {
                emptyHint("Log symptoms to see your score trend.")
            } else {
                Chart(scores, id: \.day) { point in
                    LineMark(x: .value("Day", point.day), y: .value("Score", point.score))
                        .foregroundStyle(Theme.chartAccent)
                    PointMark(x: .value("Day", point.day), y: .value("Score", point.score))
                        .foregroundStyle(Theme.chartAccent)
                    RuleMark(y: .value("Baseline", flare.baseline))
                        .lineStyle(StrokeStyle(dash: [4]))
                        .foregroundStyle(.secondary)
                }
                .frame(height: 160)
            }
        }
        .cardStyle()
    }

    private var scoreLabel: String {
        switch profile?.diagnosis {
        case .crohns: return "HBI"
        case .ulcerativeColitis: return "SCCAI"
        default: return "Symptom burden"
        }
    }

    private var bmChart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Bowel movements per day").font(.subheadline.bold())
            if bmPerDay.isEmpty {
                emptyHint("Use the Bristol quick-tap on Home to log.")
            } else {
                Chart(bmPerDay, id: \.day) { point in
                    BarMark(x: .value("Day", point.day), y: .value("Count", point.count))
                        .foregroundStyle(Theme.chartAccent.opacity(0.7))
                }
                .frame(height: 120)
            }
        }
        .cardStyle()
    }

    private var triggerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Possible triggers (eaten 4–48 h before symptom spikes)").font(.subheadline.bold())
            if correlations.isEmpty {
                emptyHint("Log meals and symptoms — patterns appear here once there's enough data.")
            } else {
                ForEach(correlations.prefix(5)) { c in
                    HStack {
                        Text(c.food).font(.subheadline)
                        Spacer()
                        Text("\(c.hits) of \(c.spikes) spikes")
                            .font(.caption.bold())
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(.orange.opacity(0.15), in: Capsule())
                            .foregroundStyle(Theme.amberText)
                    }
                }
                Text("Correlation, not proof — discuss with your care team or dietitian.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .cardStyle()
    }

    private var qolCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Quality of life (higher = better)").font(.subheadline.bold())
            if qol.isEmpty {
                emptyHint("Take a 2-minute check-in from the More tab every couple of weeks.")
            } else {
                Chart(qol.suffix(12), id: \.id) { c in
                    LineMark(x: .value("Date", c.date), y: .value("Score", c.total))
                        .foregroundStyle(Theme.chartAccent)
                    PointMark(x: .value("Date", c.date), y: .value("Score", c.total))
                        .foregroundStyle(Theme.chartAccent)
                }
                .chartYScale(domain: 0...32)
                .frame(height: 120)
            }
        }
        .cardStyle()
    }

    private func emptyHint(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 60)
    }
}
