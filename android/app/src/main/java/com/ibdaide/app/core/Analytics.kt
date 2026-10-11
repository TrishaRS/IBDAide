package com.ibdaide.app.core

import com.ibdaide.app.data.BowelMovementEntry
import com.ibdaide.app.data.Diagnosis
import com.ibdaide.app.data.DoseEvent
import com.ibdaide.app.data.FoodEntry
import com.ibdaide.app.data.Medication
import com.ibdaide.app.data.SymptomEntry
import java.util.Calendar

/** FR-2 analytics — pure functions, same behavior as iOS. */
object Analytics {

    private fun startOfDay(millis: Long): Long {
        val cal = Calendar.getInstance()
        cal.timeInMillis = millis
        cal.set(Calendar.HOUR_OF_DAY, 0); cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0); cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }

    data class DayScore(val day: Long, val score: Int)

    fun dailyScores(diagnosis: Diagnosis, symptoms: List<SymptomEntry>,
                    stools: List<BowelMovementEntry>, from: Long, to: Long): List<DayScore> {
        val symptomsByDay = symptoms.filter { it.date in from..to }.groupBy { startOfDay(it.date) }
        val stoolsByDay = stools.filter { it.date in from..to }.groupBy { startOfDay(it.date) }
        return (symptomsByDay.keys + stoolsByDay.keys).sorted().mapNotNull { day ->
            val snap = DailySnapshot.build(symptomsByDay[day] ?: emptyList(), stoolsByDay[day] ?: emptyList())
            Scoring.score(diagnosis, snap).score?.let { DayScore(day, it) }
        }
    }

    data class FlareStatus(val possibleFlare: Boolean, val baseline: Double, val elevatedDays: Int)

    fun flareStatus(scores: List<DayScore>): FlareStatus {
        val today = startOfDay(System.currentTimeMillis())
        val dayMs = 86_400_000L
        val recentCutoff = today - 7 * dayMs
        val baselineCutoff = today - 37 * dayMs

        val baselineScores = scores.filter { it.day in baselineCutoff until recentCutoff }
            .map { it.score.toDouble() }.sorted()
        val baseline = when {
            baselineScores.isEmpty() -> 2.0
            baselineScores.size % 2 == 1 -> baselineScores[baselineScores.size / 2]
            else -> (baselineScores[baselineScores.size / 2 - 1] + baselineScores[baselineScores.size / 2]) / 2
        }
        val recent = scores.filter { it.day >= recentCutoff }.takeLast(7)
        val elevated = recent.count { it.score > baseline + 2 }
        return FlareStatus(elevated >= 5 && recent.size >= 5, baseline, elevated)
    }

    data class TriggerCorrelation(val food: String, val hits: Int, val spikes: Int)

    fun triggerCorrelations(foods: List<FoodEntry>, scores: List<DayScore>, baseline: Double): List<TriggerCorrelation> {
        val spikeDays = scores.filter { it.score >= baseline + 3 }.map { it.day }
        if (spikeDays.isEmpty()) return emptyList()
        val counts = mutableMapOf<String, Int>()
        for (spike in spikeDays) {
            val spikeNoon = spike + 12 * 3_600_000L
            val windowStart = spikeNoon - 48 * 3_600_000L
            val windowEnd = spikeNoon - 4 * 3_600_000L
            foods.filter { it.date in windowStart..windowEnd }
                .map { it.name.lowercase().trim() }.filter { it.isNotEmpty() }.toSet()
                .forEach { counts[it] = (counts[it] ?: 0) + 1 }
        }
        return counts.filter { it.value >= 2 }
            .map { TriggerCorrelation(it.key.replaceFirstChar(Char::uppercase), it.value, spikeDays.size) }
            .sortedByDescending { it.hits }
    }

    fun adherencePercent(medications: List<Medication>, doses: List<DoseEvent>, from: Long, to: Long): Int? {
        val scheduled = medications.filter { it.active && it.times.isNotEmpty() }
        if (scheduled.isEmpty()) return null
        var expected = 0
        var day = startOfDay(from)
        val endDay = startOfDay(to)
        while (day <= endDay) {
            for (med in scheduled) if (med.createdAt <= day) expected += med.times.size
            day += 86_400_000L
        }
        if (expected == 0) return null
        val taken = doses.count { it.status == "taken" && it.scheduledAt in from..to }
        return minOf(100, Math.round(taken.toDouble() / expected * 100).toInt())
    }

    fun takenStreak(doses: List<DoseEvent>): Int {
        val takenDays = doses.filter { it.status == "taken" }.map { startOfDay(it.scheduledAt) }.toSet()
        var streak = 0
        var day = startOfDay(System.currentTimeMillis())
        while (day in takenDays) { streak++; day -= 86_400_000L }
        return streak
    }
}
