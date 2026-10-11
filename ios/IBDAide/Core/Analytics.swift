import Foundation

/// FR-2 analytics: daily score series, flare heuristic, trigger correlation, adherence.
/// Pure functions over in-memory arrays — easy to unit test.
enum Analytics {

    // MARK: Daily scores

    static func dailyScores(diagnosis: Diagnosis,
                            symptoms: [SymptomEntry],
                            stools: [BowelMovementEntry],
                            from start: Date, to end: Date) -> [(day: Date, score: Int)] {
        let cal = Calendar.current
        let symptomsByDay = Dictionary(grouping: symptoms.filter { $0.date >= start && $0.date <= end },
                                       by: { cal.startOfDay(for: $0.date) })
        let stoolsByDay = Dictionary(grouping: stools.filter { $0.date >= start && $0.date <= end },
                                     by: { cal.startOfDay(for: $0.date) })
        let days = Set(symptomsByDay.keys).union(stoolsByDay.keys).sorted()
        return days.compactMap { day in
            let snap = DailySnapshot.build(symptoms: symptomsByDay[day] ?? [], stools: stoolsByDay[day] ?? [])
            guard let s = Scoring.score(for: diagnosis, snapshot: snap).score else { return nil }
            return (day, s)
        }
    }

    // MARK: Flare heuristic (FR-2)

    struct FlareStatus {
        let possibleFlare: Bool
        let baseline: Double
        let elevatedDays: Int
    }

    /// Baseline = median of scores 8–37 days ago; flags a possible flare when
    /// ≥5 of the last 7 recorded days exceed baseline + 2.
    static func flareStatus(scores: [(day: Date, score: Int)]) -> FlareStatus {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let recentCutoff = cal.date(byAdding: .day, value: -7, to: today)!
        let baselineCutoff = cal.date(byAdding: .day, value: -37, to: today)!

        let baselineScores = scores.filter { $0.day >= baselineCutoff && $0.day < recentCutoff }.map { Double($0.score) }.sorted()
        let baseline: Double
        if baselineScores.isEmpty {
            baseline = 2 // assume low baseline with no history
        } else if baselineScores.count % 2 == 1 {
            baseline = baselineScores[baselineScores.count / 2]
        } else {
            baseline = (baselineScores[baselineScores.count / 2 - 1] + baselineScores[baselineScores.count / 2]) / 2
        }

        let recent = scores.filter { $0.day >= recentCutoff }.suffix(7)
        let elevated = recent.filter { Double($0.score) > baseline + 2 }.count
        return FlareStatus(possibleFlare: elevated >= 5 && recent.count >= 5, baseline: baseline, elevatedDays: elevated)
    }

    // MARK: Trigger correlation (FR-2/FR-3)

    struct TriggerCorrelation: Identifiable {
        var id: String { food }
        let food: String
        let hits: Int      // spikes preceded by this food within 4–48 h
        let spikes: Int    // total spikes considered
    }

    /// Spike day = score ≥ baseline + 3. A food "hits" if eaten 4–48 h before the spike day's noon.
    static func triggerCorrelations(foods: [FoodEntry],
                                    scores: [(day: Date, score: Int)],
                                    baseline: Double) -> [TriggerCorrelation] {
        let cal = Calendar.current
        let spikeDays = scores.filter { Double($0.score) >= baseline + 3 }.map(\.day)
        guard !spikeDays.isEmpty else { return [] }

        var counts: [String: Int] = [:]
        for spike in spikeDays {
            let spikeNoon = cal.date(byAdding: .hour, value: 12, to: spike)!
            let windowStart = spikeNoon.addingTimeInterval(-48 * 3600)
            let windowEnd = spikeNoon.addingTimeInterval(-4 * 3600)
            let eaten = foods.filter { $0.date >= windowStart && $0.date <= windowEnd }
            for name in Set(eaten.map { $0.name.lowercased().trimmingCharacters(in: .whitespaces) }) where !name.isEmpty {
                counts[name, default: 0] += 1
            }
        }
        return counts
            .filter { $0.value >= 2 }
            .map { TriggerCorrelation(food: $0.key.capitalized, hits: $0.value, spikes: spikeDays.count) }
            .sorted { $0.hits > $1.hits }
    }

    // MARK: Adherence (FR-8)

    /// Percentage of scheduled oral/injection doses recorded as taken over the period.
    static func adherencePercent(medications: [Medication], doses: [DoseEvent],
                                 from start: Date, to end: Date) -> Int? {
        let cal = Calendar.current
        let scheduled = medications.filter { $0.active && !$0.scheduleTimes.isEmpty }
        guard !scheduled.isEmpty else { return nil }

        var expected = 0
        var day = cal.startOfDay(for: start)
        let endDay = cal.startOfDay(for: end)
        while day <= endDay {
            for med in scheduled where med.createdAt <= day {
                expected += med.scheduleTimes.count
            }
            day = cal.date(byAdding: .day, value: 1, to: day)!
        }
        guard expected > 0 else { return nil }
        let taken = doses.filter { $0.status == .taken && $0.scheduledAt >= start && $0.scheduledAt <= end }.count
        return min(100, Int((Double(taken) / Double(expected) * 100).rounded()))
    }

    /// Consecutive-day streak (ending today) with at least one taken dose.
    static func takenStreak(doses: [DoseEvent]) -> Int {
        let cal = Calendar.current
        let takenDays = Set(doses.filter { $0.status == .taken }.map { cal.startOfDay(for: $0.scheduledAt) })
        var streak = 0
        var day = cal.startOfDay(for: Date())
        while takenDays.contains(day) {
            streak += 1
            day = cal.date(byAdding: .day, value: -1, to: day)!
        }
        return streak
    }
}
