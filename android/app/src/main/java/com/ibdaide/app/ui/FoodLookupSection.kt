package com.ibdaide.app.ui

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.ibdaide.app.core.FoodEvaluation
import com.ibdaide.app.core.FoodKnowledgeBase
import com.ibdaide.app.core.FoodRulesEngine
import com.ibdaide.app.core.KBSource
import com.ibdaide.app.core.OFFProduct
import com.ibdaide.app.core.OpenFoodFactsClient
import com.ibdaide.app.core.Verdict
import com.ibdaide.app.data.AppDao
import kotlinx.coroutines.launch

/** FR-15: search the built-in CCF/IOIBD knowledge base + optional Open Food Facts name search. */
@Composable
fun FoodLookupSection(dao: AppDao, triggerNames: List<String>, flareMode: Boolean) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var query by remember { mutableStateOf("") }
    var offResults by remember { mutableStateOf<List<Pair<OFFProduct, FoodEvaluation>>>(emptyList()) }
    var searching by remember { mutableStateOf(false) }
    var message by remember { mutableStateOf<String?>(null) }

    val kbResults = remember(query, flareMode) {
        FoodKnowledgeBase.search(query, triggerNames, flareMode)
    }

    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        OutlinedTextField(
            value = query,
            onValueChange = { query = it; offResults = emptyList(); message = null },
            label = { Text("Search a dish, food, or ingredient…") },
            modifier = Modifier.fillMaxWidth(),
        )

        if (query.length >= 2 && kbResults.isEmpty() && offResults.isEmpty()) {
            Text("No match in the built-in guide.", style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant)
        }

        kbResults.forEach { result ->
            when (result) {
                is FoodKnowledgeBase.LookupResult.Dish -> SectionCard {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(result.dish.name, style = MaterialTheme.typography.titleSmall)
                        VerdictChip(result.eval.overall)
                    }
                    Text(result.dish.note, style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                    result.eval.findings.take(4).forEach { FindingRow(it) }
                }
                is FoodKnowledgeBase.LookupResult.Ingredient -> SectionCard {
                    val verdict = if (flareMode) result.rule.flare else result.rule.remission
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(result.rule.name, style = MaterialTheme.typography.titleSmall)
                        VerdictChip(verdict)
                    }
                    Text(result.rule.reason, style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text("Source: ${result.rule.source.label}", style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.primary)
                }
                is FoodKnowledgeBase.LookupResult.Safe -> SectionCard {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(result.food.name, style = MaterialTheme.typography.titleSmall)
                        VerdictChip(Verdict.GREEN)
                    }
                    Text(result.food.note, style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Text("Source: ${result.food.source.label}", style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.primary)
                }
            }
        }

        if (query.length >= 3) {
            OutlinedButton(
                onClick = {
                    scope.launch {
                        searching = true; message = null
                        try {
                            val products = OpenFoodFactsClient.search(query)
                            offResults = products.map {
                                it to FoodRulesEngine.evaluate(it.ingredientsText, triggerNames, flareMode)
                            }
                            if (products.isEmpty()) message = "No packaged products with ingredient lists found for \"$query\"."
                        } catch (e: Exception) {
                            message = e.message
                        } finally {
                            searching = false
                        }
                    }
                },
                enabled = !searching,
                modifier = Modifier.fillMaxWidth(),
            ) { Text(if (searching) "Searching…" else "Check packaged products (Open Food Facts)") }
        }
        if (searching) CircularProgressIndicator(Modifier.padding(4.dp))
        message?.let { Text(it, style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant) }

        offResults.forEach { (product, eval) ->
            EvaluationCard(product.name,
                (if (product.brand.isEmpty()) "" else product.brand + " · ") + "Open Food Facts",
                eval, uncertain = false)
        }

        Column(Modifier.padding(top = 6.dp)) {
            Text("Guidance sources", style = MaterialTheme.typography.labelMedium)
            TextButton(onClick = {
                context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(KBSource.CCF.url)))
            }) { Text("Crohn's & Colitis Foundation — What Should I Eat?") }
            TextButton(onClick = {
                context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(KBSource.IOIBD.url)))
            }) { Text("IOIBD Dietary Guidance for IBD (2020)") }
            Text("Tolerance is individual. Verdicts are informational, not medical advice.",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}
