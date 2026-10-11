import Foundation

/// Clinical activity scores computed from patient-reported data.
///
/// IMPORTANT: These are *modified, patient-reported* adaptations of the
/// Harvey-Bradshaw Index (Crohn's) and the Simple Clinical Colitis Activity
/// Index (UC). They omit clinician-assessed items (e.g. abdominal mass) and
/// are informational only — for discussion with a care team, never diagnosis.

enum ScoreBand: String {
    case remission = "Remission"
    case mild = "Mild"
    case moderate = "Moderate"
    case severe = "Severe"
    case unknown = "No data"
}

struct DailySnapshot {
    /// 0–10 patient slider
    var abdominalPain: Int?
    /// 0–4 general well-being (0 very well … 4 terrible)
    var wellbeing: Int?
    /// count of Bristol 6–7 stools that day
    var liquidStools: Int
    /// total stools that day
    var totalStools: Int
    /// stools during the night
    var nightStools: Int
    /// max urgency that day: 0 none, 1 hurry, 2 immediately, 3 incontinence
    var maxUrgency: Int
    /// fraction of stools with visible blood, 0…1
    var bloodFraction: Double
    var nausea: Bool
    var jointPain: Bool
    var skinIssues: Bool
    var eyeIssues: Bool
    var mouthUlcers: Bool

    var hasAnyData: Bool {
        abdominalPain != nil || wellbeing != nil || totalStools > 0
    }
}

enum Scoring {

    /// Modified Harvey-Bradshaw Index (patient-reported subset).
    /// Well-being 0–4, pain mapped 0–3, liquid stools count, complications +1 each.
    static func modifiedHBI(_ s: DailySnapshot) -> Int? {
        guard s.hasAnyData else { return nil }
        let wellbeing = s.wellbeing ?? 0
        let pain = mapPain(s.abdominalPain)
        var complications = 0
        if s.jointPain { complications += 1 }
        if s.skinIssues { complications += 1 }
        if s.eyeIssues { complications += 1 }
        if s.mouthUlcers { complications += 1 }
        if s.nausea { complications += 1 }
        return wellbeing + pain + s.liquidStools + complications
    }

    static func hbiBand(_ score: Int?) -> ScoreBand {
        guard let score else { return .unknown }
        switch score {
        case ..<5: return .remission
        case 5...7: return .mild
        case 8...16: return .moderate
        default: return .severe
        }
    }

    /// Modified SCCAI (patient-reported subset).
    static func modifiedSCCAI(_ s: DailySnapshot) -> Int? {
        guard s.hasAnyData else { return nil }
        var score = 0
        // Bowel frequency (day)
        switch s.totalStools - s.nightStools {
        case ..<4: score += 0
        case 4...6: score += 1
        case 7...9: score += 2
        default: score += 3
        }
        // Bowel frequency (night)
        switch s.nightStools {
        case 0: score += 0
        case 1...3: score += 1
        default: score += 2
        }
        // Urgency 0–3
        score += min(max(s.maxUrgency, 0), 3)
        // Blood 0–3
        switch s.bloodFraction {
        case 0: score += 0
        case ..<0.25: score += 1
        case ..<0.75: score += 2
        default: score += 3
        }
        // General well-being 0–4 (SCCAI caps at 4 with our scale)
        score += min(s.wellbeing ?? 0, 4)
        // Extracolonic manifestations +1 each
        if s.jointPain { score += 1 }
        if s.skinIssues { score += 1 }
        if s.eyeIssues { score += 1 }
        if s.mouthUlcers { score += 1 }
        return score
    }

    static func sccaiBand(_ score: Int?) -> ScoreBand {
        guard let score else { return .unknown }
        switch score {
        case ..<3: return .remission
        case 3...6: return .mild
        case 7...11: return .moderate
        default: return .severe
        }
    }

    static func score(for diagnosis: Diagnosis, snapshot: DailySnapshot) -> (score: Int?, band: ScoreBand, label: String) {
        switch diagnosis {
        case .crohns:
            let s = modifiedHBI(snapshot)
            return (s, hbiBand(s), "HBI")
        case .ulcerativeColitis:
            let s = modifiedSCCAI(snapshot)
            return (s, sccaiBand(s), "SCCAI")
        case .ibdU:
            // No validated single score; use symptom burden (pain map + liquid stools + urgency)
            guard snapshot.hasAnyData else { return (nil, .unknown, "Symptom burden") }
            let s = mapPain(snapshot.abdominalPain) + snapshot.liquidStools + snapshot.maxUrgency
            let band: ScoreBand = s < 3 ? .remission : s < 6 ? .mild : s < 10 ? .moderate : .severe
            return (s, band, "Symptom burden")
        }
    }

    /// Band for an already-computed score under the given diagnosis.
    static func band(for diagnosis: Diagnosis, score: Int) -> ScoreBand {
        switch diagnosis {
        case .crohns: return hbiBand(score)
        case .ulcerativeColitis: return sccaiBand(score)
        case .ibdU:
            return score < 3 ? .remission : score < 6 ? .mild : score < 10 ? .moderate : .severe
        }
    }

    /// Map a 0–10 pain slider to the 0–3 index scale.
    static func mapPain(_ pain: Int?) -> Int {
        guard let pain else { return 0 }
        switch pain {
        case ..<1: return 0
        case 1...3: return 1
        case 4...6: return 2
        default: return 3
        }
    }
}

// MARK: - Snapshot builder from model data

extension DailySnapshot {
    /// Builds the day's snapshot from raw entries (all entries must belong to the same calendar day).
    static func build(symptoms: [SymptomEntry], stools: [BowelMovementEntry]) -> DailySnapshot {
        let latest = symptoms.max(by: { $0.date < $1.date })
        let liquid = stools.filter { $0.bristol >= 6 }.count
        let blood = stools.isEmpty ? 0.0 : Double(stools.filter(\.blood).count) / Double(stools.count)
        return DailySnapshot(
            abdominalPain: latest?.abdominalPain,
            wellbeing: latest?.wellbeing,
            liquidStools: liquid,
            totalStools: stools.count,
            nightStools: stools.filter(\.nighttime).count,
            maxUrgency: stools.map(\.urgency).max() ?? 0,
            bloodFraction: blood,
            nausea: latest?.nausea ?? false,
            jointPain: latest?.jointPain ?? false,
            skinIssues: latest?.skinIssues ?? false,
            eyeIssues: latest?.eyeIssues ?? false,
            mouthUlcers: latest?.mouthUlcers ?? false
        )
    }
}
