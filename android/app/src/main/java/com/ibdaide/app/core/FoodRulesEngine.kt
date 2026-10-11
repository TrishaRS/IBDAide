package com.ibdaide.app.core

/** Same evaluation logic as iOS — worst match wins; personal triggers always Avoid. */

data class FoodFinding(
    val ingredient: String,
    val verdict: Verdict,
    val reason: String,
    val isPersonalTrigger: Boolean,
    val source: KBSource,
)

data class FoodEvaluation(
    val overall: Verdict,
    val findings: List<FoodFinding>,
    val safeFindings: List<FoodFinding>,
    val flareMode: Boolean,
    val dishName: String? = null,
    val dishNote: String? = null,
)

object FoodRulesEngine {

    fun evaluate(ingredientsText: String, personalTriggers: List<String>, flareMode: Boolean): FoodEvaluation {
        val normalized = " " + ingredientsText.lowercase() + " "
        val ingredients = ingredientsText.lowercase()
            .split(',', ';', '\n', '•', '(')
            .map { it.trim(' ', ')', '.', '\t') }
            .filter { it.isNotEmpty() }

        val findings = mutableListOf<FoodFinding>()
        val safeFindings = mutableListOf<FoodFinding>()
        val matchedKeywords = mutableSetOf<String>()

        // 1. Personal triggers — always Avoid.
        for (trigger in personalTriggers) {
            val t = trigger.lowercase().trim()
            if (t.isEmpty() || !normalized.contains(t)) continue
            val matched = ingredients.firstOrNull { it.contains(t) } ?: trigger
            findings += FoodFinding(matched.replaceFirstChar(Char::uppercase), Verdict.AVOID,
                "You marked \"$trigger\" as a personal trigger", true, KBSource.APP)
            matchedKeywords += t
        }

        // 2. Knowledge-base rules.
        for (rule in FoodKnowledgeBase.rules) {
            for (keyword in rule.keywords) {
                if (!normalized.contains(keyword)) continue
                val verdict = if (flareMode) rule.flare else rule.remission
                if (verdict == Verdict.GREEN) break
                if (keyword in matchedKeywords) break
                matchedKeywords += keyword
                val matched = ingredients.firstOrNull { it.contains(keyword) } ?: rule.name
                findings += FoodFinding(matched.replaceFirstChar(Char::uppercase), verdict,
                    rule.reason, false, rule.source)
                break
            }
        }

        // 3. Recognized well-tolerated foods.
        for (safe in FoodKnowledgeBase.safeFoods) {
            for (keyword in safe.keywords) {
                if (!normalized.contains(keyword)) continue
                if (matchedKeywords.any { keyword.contains(it) || it.contains(keyword) }) break
                safeFindings += FoodFinding(safe.name, Verdict.GREEN, safe.note, false, safe.source)
                break
            }
        }

        val overall = findings.maxOfOrNull { it.verdict } ?: Verdict.GREEN
        return FoodEvaluation(
            overall = overall,
            findings = findings.sortedByDescending { it.verdict },
            safeFindings = safeFindings.take(6),
            flareMode = flareMode,
        )
    }

    fun evaluateDish(labels: List<String>, inferredIngredients: List<String>,
                     personalTriggers: List<String>, flareMode: Boolean): FoodEvaluation {
        val dish = FoodKnowledgeBase.dishForLabels(labels)
        val combined = (inferredIngredients.map { it.lowercase() } +
                (dish?.typicalIngredients?.map { it.lowercase() } ?: emptyList())).toSet()
        val eval = evaluate(combined.joinToString(", "), personalTriggers, flareMode)
        return eval.copy(dishName = dish?.name, dishNote = dish?.note)
    }
}
