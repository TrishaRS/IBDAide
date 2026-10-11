package com.ibdaide.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.ibdaide.app.core.FoodEvaluation
import com.ibdaide.app.core.FoodFinding
import com.ibdaide.app.core.KBSource
import com.ibdaide.app.core.Verdict
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

fun formatDate(millis: Long): String =
    SimpleDateFormat("EEE, MMM d · h:mm a", Locale.US).format(Date(millis))

fun formatDay(millis: Long): String =
    SimpleDateFormat("MMM d, yyyy", Locale.US).format(Date(millis))

fun minutesLabel(minutes: Int): String = "%d:%02d".format(minutes / 60, minutes % 60)

@Composable
fun SectionCard(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    Card(modifier = modifier.fillMaxWidth()) {
        Column(Modifier.padding(12.dp), content = content)
    }
}

@Composable
fun VerdictChip(verdict: Verdict, personal: Boolean = false) {
    val color = Brand.verdictColor(verdict)
    Text(
        text = if (personal) "Your trigger" else verdict.label,
        style = MaterialTheme.typography.labelSmall,
        color = verdictTextColor(verdict),
        modifier = Modifier
            .background(color.copy(alpha = 0.15f), RoundedCornerShape(50))
            .padding(horizontal = 10.dp, vertical = 4.dp),
    )
}

@Composable
fun FindingRow(f: FoodFinding, uncertain: Boolean = false) {
    androidx.compose.foundation.layout.Row(
        Modifier.fillMaxWidth().padding(vertical = 3.dp),
        horizontalArrangement = androidx.compose.foundation.layout.Arrangement.SpaceBetween,
    ) {
        Column(Modifier.weight(1f)) {
            Text(if (uncertain) "Likely: ${f.ingredient}" else f.ingredient,
                style = MaterialTheme.typography.bodyMedium)
            Text(f.reason + if (f.source == KBSource.APP) "" else " — ${f.source.label}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        VerdictChip(f.verdict, f.isPersonalTrigger)
    }
}

@Composable
fun EvaluationCard(title: String, subtitle: String, eval: FoodEvaluation, uncertain: Boolean) {
    SectionCard {
        androidx.compose.foundation.layout.Row(
            Modifier.fillMaxWidth(),
            horizontalArrangement = androidx.compose.foundation.layout.Arrangement.SpaceBetween,
        ) {
            Column(Modifier.weight(1f)) {
                Text(title, style = MaterialTheme.typography.titleMedium)
                Text(subtitle, style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            VerdictChip(eval.overall)
        }
        if (eval.flareMode) {
            Text("Flare mode: stricter rules applied", style = MaterialTheme.typography.bodySmall,
                color = amberText())
        }
        eval.dishNote?.let {
            Text(it, style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        if (eval.findings.isEmpty()) {
            Text(if (uncertain) "No flagged ingredients among the likely contents."
                 else "No flagged ingredients found.",
                style = MaterialTheme.typography.bodyMedium, color = greenText())
        } else {
            eval.findings.forEach { FindingRow(it, uncertain) }
        }
        eval.safeFindings.forEach { f ->
            Text("✓ ${f.ingredient} — ${f.reason}", style = MaterialTheme.typography.bodySmall,
                color = greenText())
        }
    }
}
