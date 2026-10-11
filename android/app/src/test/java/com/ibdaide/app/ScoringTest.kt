package com.ibdaide.app

import com.ibdaide.app.core.DailySnapshot
import com.ibdaide.app.core.ExportEnvelope
import com.ibdaide.app.core.ExportManager
import com.ibdaide.app.core.FoodKnowledgeBase
import com.ibdaide.app.core.FoodRulesEngine
import com.ibdaide.app.core.KBSource
import com.ibdaide.app.core.ScoreBand
import com.ibdaide.app.core.Scoring
import com.ibdaide.app.core.Verdict
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

/** Shared cross-platform test vectors — identical inputs/outputs to iOS ScoringTests. */
class ScoringTest {

    private fun snap(pain: Int? = null, wellbeing: Int? = null, liquid: Int = 0, total: Int = 0,
                     night: Int = 0, urgency: Int = 0, blood: Double = 0.0,
                     nausea: Boolean = false, joint: Boolean = false) =
        DailySnapshot(pain, wellbeing, liquid, total, night, urgency, blood,
            nausea, joint, skinIssues = false, eyeIssues = false, mouthUlcers = false)

    @Test fun hbiAllQuiet() {
        assertEquals(0, Scoring.modifiedHBI(snap(pain = 0, wellbeing = 0, total = 1)))
        assertEquals(ScoreBand.REMISSION, Scoring.hbiBand(0))
    }

    @Test fun hbiModerateFlare() {
        // wellbeing 3 + pain 7→3 + 4 liquid + joint 1 + nausea 1 = 12 → moderate
        val s = snap(pain = 7, wellbeing = 3, liquid = 4, total = 6, night = 1,
            urgency = 2, blood = 0.5, nausea = true, joint = true)
        assertEquals(12, Scoring.modifiedHBI(s))
        assertEquals(ScoreBand.MODERATE, Scoring.hbiBand(12))
    }

    @Test fun hbiNoData() {
        assertNull(Scoring.modifiedHBI(snap()))
        assertEquals(ScoreBand.UNKNOWN, Scoring.hbiBand(null))
    }

    @Test fun sccaiRemission() {
        // 2 day stools (0) + 0 night + urgency 0 + blood 0 + wellbeing 1 = 1 → remission
        assertEquals(1, Scoring.modifiedSCCAI(snap(pain = 1, wellbeing = 1, total = 2)))
        assertEquals(ScoreBand.REMISSION, Scoring.sccaiBand(1))
    }

    @Test fun sccaiActive() {
        // 8 day (2) + 2 night (1) + urgency 2 + blood 0.5→2 + wellbeing 3 + joint 1 = 11 → moderate
        val s = snap(pain = 5, wellbeing = 3, liquid = 6, total = 10, night = 2,
            urgency = 2, blood = 0.5, joint = true)
        assertEquals(11, Scoring.modifiedSCCAI(s))
        assertEquals(ScoreBand.MODERATE, Scoring.sccaiBand(11))
    }

    @Test fun painMapping() {
        assertEquals(0, Scoring.mapPain(null))
        assertEquals(0, Scoring.mapPain(0))
        assertEquals(1, Scoring.mapPain(2))
        assertEquals(2, Scoring.mapPain(5))
        assertEquals(3, Scoring.mapPain(10))
    }

    // MARK: Food knowledge base

    @Test fun personalTriggerAlwaysAvoid() {
        val eval = FoodRulesEngine.evaluate("oats, honey, almonds, salt", listOf("almonds"), flareMode = false)
        assertEquals(Verdict.AVOID, eval.overall)
        assertTrue(eval.findings.any { it.isPersonalTrigger })
    }

    @Test fun flareModeEscalates() {
        val remission = FoodRulesEngine.evaluate("chicory root fiber, water", emptyList(), flareMode = false)
        val flare = FoodRulesEngine.evaluate("chicory root fiber, water", emptyList(), flareMode = true)
        assertEquals(Verdict.CAUTION, remission.overall)
        assertEquals(Verdict.AVOID, flare.overall)
    }

    @Test fun cleanIngredientsGreen() {
        val eval = FoodRulesEngine.evaluate("water, white rice, chicken breast, salt", emptyList(), flareMode = true)
        assertEquals(Verdict.GREEN, eval.overall)
        assertTrue(eval.findings.isEmpty())
        assertFalse(eval.safeFindings.isEmpty())
    }

    @Test fun dishInventoryFlagsFriedChickenInFlare() {
        val eval = FoodRulesEngine.evaluateDish(listOf("fried chicken"), emptyList(), emptyList(), flareMode = true)
        assertEquals("Fried chicken", eval.dishName)
        assertEquals(Verdict.AVOID, eval.overall)
    }

    @Test fun ioibdAdditiveFlagged() {
        val eval = FoodRulesEngine.evaluate("water, maltodextrin, polysorbate 80", emptyList(), flareMode = false)
        assertTrue(eval.findings.any { it.source == KBSource.IOIBD })
        assertEquals(Verdict.CAUTION, eval.overall)
    }

    @Test fun kbLookupFindsDishAndSafeFood() {
        assertFalse(FoodKnowledgeBase.search("pizza", emptyList(), false).isEmpty())
        assertFalse(FoodKnowledgeBase.search("banana", emptyList(), false).isEmpty())
    }

    // MARK: Export crypto round-trip

    @Test fun exportEncryptDecryptRoundTrip() {
        val env = ExportEnvelope().apply {
            profile = ExportEnvelope.ProfileDTO().apply { name = "Test"; diagnosis = "Crohn's disease" }
        }
        val data = ExportManager.encrypt(env, "correct horse battery")
        val restored = ExportManager.decrypt(data, "correct horse battery")
        assertEquals("Test", restored.profile?.name)
        assertThrows(ExportManager.BadPassphraseException::class.java) {
            ExportManager.decrypt(data, "wrong")
        }
    }
}
