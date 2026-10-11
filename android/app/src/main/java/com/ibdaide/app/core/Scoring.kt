package com.ibdaide.app.core

import com.ibdaide.app.data.BowelMovementEntry
import com.ibdaide.app.data.Diagnosis
import com.ibdaide.app.data.SymptomEntry

/**
 * Modified, patient-reported adaptations of HBI (Crohn's) and SCCAI (UC).
 * Same logic and test vectors as the iOS implementation — informational only.
 */

enum class ScoreBand(val label: String) {
    REMISSION("Remission"), MILD("Mild"), MODERATE("Moderate"), SEVERE("Severe"), UNKNOWN("No data")
}

data class DailySnapshot(
    val abdominalPain: Int?,
    val wellbeing: Int?,
    val liquidStools: Int,
    val totalStools: Int,
    val nightStools: Int,
    val maxUrgency: Int,
    val bloodFraction: Double,
    val nausea: Boolean,
    val jointPain: Boolean,
    val skinIssues: Boolean,
    val eyeIssues: Boolean,
    val mouthUlcers: Boolean,
) {
    val hasAnyData: Boolean get() = abdominalPain != null || wellbeing != null || totalStools > 0

    companion object {
        /** Build from one calendar day's entries. */
        fun build(symptoms: List<SymptomEntry>, stools: List<BowelMovementEntry>): DailySnapshot {
            val latest = symptoms.maxByOrNull { it.date }
            val blood = if (stools.isEmpty()) 0.0 else stools.count { it.blood }.toDouble() / stools.size
            return DailySnapshot(
                abdominalPain = latest?.abdominalPain,
                wellbeing = latest?.wellbeing,
                liquidStools = stools.count { it.bristol >= 6 },
                totalStools = stools.size,
                nightStools = stools.count { it.nighttime },
                maxUrgency = stools.maxOfOrNull { it.urgency } ?: 0,
                bloodFraction = blood,
                nausea = latest?.nausea ?: false,
                jointPain = latest?.jointPain ?: false,
                skinIssues = latest?.skinIssues ?: false,
                eyeIssues = latest?.eyeIssues ?: false,
                mouthUlcers = latest?.mouthUlcers ?: false,
            )
        }
    }
}

object Scoring {

    fun mapPain(pain: Int?): Int = when {
        pain == null || pain < 1 -> 0
        pain <= 3 -> 1
        pain <= 6 -> 2
        else -> 3
    }

    fun modifiedHBI(s: DailySnapshot): Int? {
        if (!s.hasAnyData) return null
        var complications = 0
        if (s.jointPain) complications++
        if (s.skinIssues) complications++
        if (s.eyeIssues) complications++
        if (s.mouthUlcers) complications++
        if (s.nausea) complications++
        return (s.wellbeing ?: 0) + mapPain(s.abdominalPain) + s.liquidStools + complications
    }

    fun hbiBand(score: Int?): ScoreBand = when {
        score == null -> ScoreBand.UNKNOWN
        score < 5 -> ScoreBand.REMISSION
        score <= 7 -> ScoreBand.MILD
        score <= 16 -> ScoreBand.MODERATE
        else -> ScoreBand.SEVERE
    }

    fun modifiedSCCAI(s: DailySnapshot): Int? {
        if (!s.hasAnyData) return null
        var score = 0
        score += when (s.totalStools - s.nightStools) {
            in Int.MIN_VALUE..3 -> 0; in 4..6 -> 1; in 7..9 -> 2; else -> 3
        }
        score += when (s.nightStools) { 0 -> 0; in 1..3 -> 1; else -> 2 }
        score += s.maxUrgency.coerceIn(0, 3)
        score += when {
            s.bloodFraction <= 0.0 -> 0
            s.bloodFraction < 0.25 -> 1
            s.bloodFraction < 0.75 -> 2
            else -> 3
        }
        score += (s.wellbeing ?: 0).coerceAtMost(4)
        if (s.jointPain) score++
        if (s.skinIssues) score++
        if (s.eyeIssues) score++
        if (s.mouthUlcers) score++
        return score
    }

    fun sccaiBand(score: Int?): ScoreBand = when {
        score == null -> ScoreBand.UNKNOWN
        score < 3 -> ScoreBand.REMISSION
        score <= 6 -> ScoreBand.MILD
        score <= 11 -> ScoreBand.MODERATE
        else -> ScoreBand.SEVERE
    }

    data class Result(val score: Int?, val band: ScoreBand, val label: String)

    fun score(diagnosis: Diagnosis, snapshot: DailySnapshot): Result = when (diagnosis) {
        Diagnosis.CROHNS -> modifiedHBI(snapshot).let { Result(it, hbiBand(it), "HBI") }
        Diagnosis.ULCERATIVE_COLITIS -> modifiedSCCAI(snapshot).let { Result(it, sccaiBand(it), "SCCAI") }
        Diagnosis.IBD_U -> {
            if (!snapshot.hasAnyData) Result(null, ScoreBand.UNKNOWN, "Symptom burden")
            else {
                val s = mapPain(snapshot.abdominalPain) + snapshot.liquidStools + snapshot.maxUrgency
                val band = when { s < 3 -> ScoreBand.REMISSION; s < 6 -> ScoreBand.MILD; s < 10 -> ScoreBand.MODERATE; else -> ScoreBand.SEVERE }
                Result(s, band, "Symptom burden")
            }
        }
    }
}
