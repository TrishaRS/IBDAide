package com.ibdaide.app.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.FilterChip
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp
import com.ibdaide.app.core.Analytics
import com.ibdaide.app.data.AppDao

@Composable
fun TrendsScreen(dao: AppDao, modifier: Modifier = Modifier) {
    val profile by dao.profileFlow().collectAsState(initial = null)
    val symptoms by dao.symptomsFlow().collectAsState(initial = emptyList())
    val stools by dao.bmsFlow().collectAsState(initial = emptyList())
    val foods by dao.foodsFlow().collectAsState(initial = emptyList())
    val qol by dao.qolFlow().collectAsState(initial = emptyList())

    var rangeDays by remember { mutableIntStateOf(30) }
    val now = System.currentTimeMillis()
    val start = now - rangeDays * 86_400_000L

    val diagnosis = profile?.diagnosis ?: return
    val scores = Analytics.dailyScores(diagnosis, symptoms, stools, start, now)
    val allScores = Analytics.dailyScores(diagnosis, symptoms, stools, now - 40 * 86_400_000L, now)
    val flare = Analytics.flareStatus(allScores)
    val correlations = Analytics.triggerCorrelations(foods, scores, flare.baseline)

    Column(
        modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text("Trends", style = MaterialTheme.typography.headlineSmall)

        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf(7 to "Week", 30 to "Month", 365 to "Year").forEach { (days, label) ->
                FilterChip(selected = rangeDays == days, onClick = { rangeDays = days }, label = { Text(label) })
            }
        }

        if (flare.possibleFlare) {
            SectionCard {
                Text("⚠ Possible flare pattern", style = MaterialTheme.typography.titleSmall, color = amberText())
                Text("Your score has been above your usual baseline on ${flare.elevatedDays} of the last 7 logged days. Consider contacting your care team.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }

        SectionCard {
            Text("${Analytics.run { if (diagnosis == com.ibdaide.app.data.Diagnosis.CROHNS) "HBI" else if (diagnosis == com.ibdaide.app.data.Diagnosis.ULCERATIVE_COLITIS) "SCCAI" else "Symptom burden" }} score",
                style = MaterialTheme.typography.titleSmall)
            if (scores.isEmpty()) EmptyHint("Log symptoms to see your score trend.")
            else LineChart(scores.map { it.score.toFloat() }, baseline = flare.baseline.toFloat())
        }

        SectionCard {
            Text("Bowel movements per day", style = MaterialTheme.typography.titleSmall)
            val byDay = stools.filter { it.date >= start }
                .groupBy { it.date / 86_400_000L }.toSortedMap().values.map { it.size.toFloat() }
            if (byDay.isEmpty()) EmptyHint("Use the Bristol quick-tap on Home to log.")
            else BarChart(byDay)
        }

        SectionCard {
            Text("Possible triggers (eaten 4–48 h before symptom spikes)", style = MaterialTheme.typography.titleSmall)
            if (correlations.isEmpty()) EmptyHint("Log meals and symptoms — patterns appear here once there's enough data.")
            else {
                correlations.take(5).forEach { c ->
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(c.food, style = MaterialTheme.typography.bodyMedium)
                        Text("${c.hits} of ${c.spikes} spikes", style = MaterialTheme.typography.labelMedium, color = amberText())
                    }
                }
                Text("Correlation, not proof — discuss with your care team or dietitian.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }

        SectionCard {
            Text("Quality of life (higher = better)", style = MaterialTheme.typography.titleSmall)
            if (qol.isEmpty()) EmptyHint("Take a 2-minute check-in from the More tab every couple of weeks.")
            else LineChart(qol.takeLast(12).map { it.total.toFloat() }, maxValue = 32f)
        }
    }
}

@Composable
private fun EmptyHint(text: String) {
    Text(text, style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(vertical = 16.dp))
}

@Composable
fun LineChart(values: List<Float>, baseline: Float? = null, maxValue: Float? = null) {
    if (values.isEmpty()) return
    val maxV = maxValue ?: maxOf(values.max(), 1f)
    val minV = minOf(values.min(), 0f)
    val range = maxOf(maxV - minV, 1f)
    Canvas(Modifier.fillMaxWidth().height(140.dp).padding(top = 8.dp)) {
        val w = size.width; val h = size.height
        fun y(v: Float) = h - h * ((v - minV) / range)
        // baseline
        baseline?.let {
            drawLine(Brand.Amber.copy(alpha = 0.5f), Offset(0f, y(it)), Offset(w, y(it)), strokeWidth = 2f)
        }
        val path = Path()
        values.forEachIndexed { i, v ->
            val x = if (values.size == 1) w / 2 else w * i / (values.size - 1)
            if (i == 0) path.moveTo(x, y(v)) else path.lineTo(x, y(v))
        }
        drawPath(path, Brand.Teal, style = Stroke(width = 5f))
        values.forEachIndexed { i, v ->
            val x = if (values.size == 1) w / 2 else w * i / (values.size - 1)
            drawCircle(Brand.Teal, radius = 7f, center = Offset(x, y(v)))
        }
    }
}

@Composable
fun BarChart(values: List<Float>) {
    if (values.isEmpty()) return
    val maxV = maxOf(values.max(), 1f)
    Canvas(Modifier.fillMaxWidth().height(110.dp).padding(top = 8.dp)) {
        val w = size.width; val h = size.height
        val barW = w / values.size * 0.7f
        values.forEachIndexed { i, v ->
            val x = w * i / values.size + (w / values.size - barW) / 2
            val barH = h * (v / maxV)
            drawRoundRect(Brand.Teal.copy(alpha = 0.7f), topLeft = Offset(x, h - barH),
                size = androidx.compose.ui.geometry.Size(barW, barH),
                cornerRadius = androidx.compose.ui.geometry.CornerRadius(6f, 6f))
        }
    }
}
