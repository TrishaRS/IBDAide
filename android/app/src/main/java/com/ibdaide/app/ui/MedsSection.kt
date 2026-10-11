package com.ibdaide.app.ui

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.FilterChip
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.ibdaide.app.core.Analytics
import com.ibdaide.app.core.Reminders
import com.ibdaide.app.data.AppDao
import com.ibdaide.app.data.Medication
import com.ibdaide.app.data.MedicationKind
import kotlinx.coroutines.launch
import java.util.Calendar

/** Screen 5 — FR-8: medications, adherence, refills. Lives in Care ▸ Meds. */
@Composable
fun MedsSection(dao: AppDao) {
    val scope = rememberCoroutineScope()
    val meds by dao.medsFlow().collectAsState(initial = emptyList())
    val doses by dao.dosesFlow().collectAsState(initial = emptyList())
    var editing by remember { mutableStateOf<Medication?>(null) }
    var showNew by remember { mutableStateOf(false) }

    val now = System.currentTimeMillis()
    val adherence = Analytics.adherencePercent(meds, doses, now - 30 * 86_400_000L, now)

    val refillSoon = meds.filter { med ->
        med.active && (
            (med.refillDate != null && med.refillDate - now < 7 * 86_400_000L) ||
            (med.pillsRemaining != null && med.times.isNotEmpty() && med.pillsRemaining <= med.times.size * 7))
    }

    Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Button(onClick = { showNew = true }) { Text("＋ Add medication") }

        refillSoon.forEach { med ->
            SectionCard {
                Text("🔔 Refill soon — ${med.name}", style = MaterialTheme.typography.titleSmall, color = amberText())
            }
        }

        // Today's doses
        SectionCard {
            Text("Today", style = MaterialTheme.typography.titleSmall)
            val today = Calendar.getInstance().apply {
                set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0)
            }.timeInMillis
            val todayEvents = doses.filter { it.scheduledAt >= today }
            val schedule = meds.filter { it.active }.flatMap { med -> med.times.map { med to it } }.sortedBy { it.second }
            if (schedule.isEmpty()) Text("No scheduled doses today.",
                style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            schedule.forEach { (med, minutes) ->
                val status = todayEvents.firstOrNull { e ->
                    val c = Calendar.getInstance(); c.timeInMillis = e.scheduledAt
                    e.medicationID == med.id && c.get(Calendar.HOUR_OF_DAY) == minutes / 60
                }?.status
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text("${med.name} ${med.dose}", style = MaterialTheme.typography.bodyMedium)
                        Text(minutesLabel(minutes), style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    when (status) {
                        "taken" -> Text("✓ taken", color = greenText(), style = MaterialTheme.typography.labelMedium)
                        "skipped" -> Text("skipped", color = amberText(), style = MaterialTheme.typography.labelMedium)
                        else -> Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            Button(onClick = { scope.launch { recordDose(dao, med.id, minutes, "taken") } }) { Text("Taken") }
                            OutlinedButton(onClick = { scope.launch { recordDose(dao, med.id, minutes, "skipped") } }) { Text("Skip") }
                        }
                    }
                }
            }
        }

        // All medications
        meds.forEach { med ->
            SectionCard(Modifier.clickable { editing = med }) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(med.name + if (med.active) "" else " (inactive)", style = MaterialTheme.typography.titleSmall)
                    if (med.kind == MedicationKind.INFUSION) med.intervalWeeks?.let {
                        Text("every $it wks", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
                    }
                }
                Text("${med.dose} · ${med.kind.label}", style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }

        // Adherence
        SectionCard {
            Text("Adherence (30 days)", style = MaterialTheme.typography.titleSmall)
            if (adherence != null) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("$adherence% taken", style = MaterialTheme.typography.bodyMedium)
                    Text("${Analytics.takenStreak(doses)}-day streak", style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                LinearProgressIndicator(progress = { adherence / 100f }, modifier = Modifier.fillMaxWidth())
            } else {
                Text("Add a scheduled medication to track adherence.",
                    style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
    }

    if (showNew) MedicationEditDialog(dao, null) { showNew = false }
    editing?.let { med -> MedicationEditDialog(dao, med) { editing = null } }
}

@Composable
private fun MedicationEditDialog(dao: AppDao, medication: Medication?, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var name by remember { mutableStateOf(medication?.name ?: "") }
    var dose by remember { mutableStateOf(medication?.dose ?: "") }
    var kind by remember { mutableStateOf(medication?.kind ?: MedicationKind.ORAL) }
    var times by remember { mutableStateOf(medication?.times ?: listOf(8 * 60)) }
    var intervalWeeks by remember { mutableIntStateOf(medication?.intervalWeeks ?: 8) }
    var trackPills by remember { mutableStateOf(medication?.pillsRemaining != null) }
    var pills by remember { mutableStateOf((medication?.pillsRemaining ?: 30).toString()) }
    var active by remember { mutableStateOf(medication?.active ?: true) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (medication == null) "New medication" else "Edit medication") },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(value = name, onValueChange = { name = it }, label = { Text("Name") })
                OutlinedTextField(value = dose, onValueChange = { dose = it }, label = { Text("Dose (e.g. 800 mg)") })
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    MedicationKind.entries.forEach { k ->
                        FilterChip(selected = kind == k, onClick = { kind = k },
                            label = { Text(k.label, style = MaterialTheme.typography.labelSmall) })
                    }
                }
                if (kind == MedicationKind.INFUSION) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Text("Every ")
                        FilterChip(selected = false, onClick = { if (intervalWeeks > 1) intervalWeeks-- }, label = { Text("−") })
                        Text(" $intervalWeeks weeks ")
                        FilterChip(selected = false, onClick = { if (intervalWeeks < 16) intervalWeeks++ }, label = { Text("＋") })
                    }
                    Text("Create the matching IV appointment in Care ▸ Appointments for reminders.",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                } else {
                    Text("Daily reminder times", style = MaterialTheme.typography.titleSmall)
                    times.forEachIndexed { i, t ->
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                            Text(minutesLabel(t))
                            FilterChip(selected = false, onClick = {
                                times = times.toMutableList().also { it[i] = (t + 24 * 60 - 30) % (24 * 60) }
                            }, label = { Text("−30m") })
                            FilterChip(selected = false, onClick = {
                                times = times.toMutableList().also { it[i] = (t + 30) % (24 * 60) }
                            }, label = { Text("+30m") })
                            TextButton(onClick = { times = times.filterIndexed { j, _ -> j != i } }) { Text("✕") }
                        }
                    }
                    TextButton(onClick = { times = times + (20 * 60) }) { Text("＋ Add time") }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Switch(checked = trackPills, onCheckedChange = { trackPills = it })
                        Text("  Track pills remaining")
                    }
                    if (trackPills) OutlinedTextField(value = pills, onValueChange = { pills = it },
                        label = { Text("Pills left") })
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Switch(checked = active, onCheckedChange = { active = it }); Text("  Active")
                }
            }
        },
        confirmButton = {
            Button(onClick = {
                scope.launch {
                    val m = (medication ?: Medication()).copy(
                        name = name, dose = dose, kindRaw = kind.label, active = active,
                        scheduleTimes = if (kind == MedicationKind.INFUSION) "" else times.joinToString(","),
                        intervalWeeks = if (kind == MedicationKind.INFUSION) intervalWeeks else null,
                        pillsRemaining = if (trackPills) pills.toIntOrNull() else null)
                    dao.upsert(m)
                    Reminders.scheduleMedReminders(context, m)
                    Reminders.scheduleRefillAlert(context, m)
                    onDismiss()
                }
            }, enabled = name.isNotBlank()) { Text("Save") }
        },
        dismissButton = {
            Row {
                if (medication != null) TextButton(onClick = {
                    scope.launch {
                        Reminders.cancelMedReminders(context, medication)
                        dao.delete(medication); onDismiss()
                    }
                }) { Text("Delete", color = Brand.Red) }
                TextButton(onClick = onDismiss) { Text("Cancel") }
            }
        },
    )
}
