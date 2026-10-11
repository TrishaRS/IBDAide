package com.ibdaide.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.Button
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.ibdaide.app.core.DailySnapshot
import com.ibdaide.app.core.Scoring
import com.ibdaide.app.data.AppDao
import com.ibdaide.app.data.BowelMovementEntry
import com.ibdaide.app.data.FoodEntry
import com.ibdaide.app.data.HydrationEntry
import com.ibdaide.app.data.SymptomEntry
import com.ibdaide.app.data.TriggerFood
import kotlinx.coroutines.launch
import java.util.Calendar

private fun startOfToday(): Long {
    val cal = Calendar.getInstance()
    cal.set(Calendar.HOUR_OF_DAY, 0); cal.set(Calendar.MINUTE, 0)
    cal.set(Calendar.SECOND, 0); cal.set(Calendar.MILLISECOND, 0)
    return cal.timeInMillis
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(dao: AppDao, modifier: Modifier = Modifier) {
    val scope = rememberCoroutineScope()
    val profile by dao.profileFlow().collectAsState(initial = null)
    val symptoms by dao.symptomsFlow().collectAsState(initial = emptyList())
    val stools by dao.bmsFlow().collectAsState(initial = emptyList())
    val appointments by dao.appointmentsFlow().collectAsState(initial = emptyList())
    val meds by dao.medsFlow().collectAsState(initial = emptyList())
    val doses by dao.dosesFlow().collectAsState(initial = emptyList())
    val questions by dao.questionsFlow().collectAsState(initial = emptyList())

    var showSymptomLog by remember { mutableStateOf(false) }
    var showMealSheet by remember { mutableStateOf(false) }
    var bristolPick by remember { mutableStateOf<Int?>(null) }
    var bmBlood by remember { mutableStateOf(false) }
    var bmUrgency by remember { mutableStateOf(0) }

    val today = startOfToday()
    val score = profile?.let { p ->
        Scoring.score(p.diagnosis, DailySnapshot.build(
            symptoms.filter { it.date >= today }, stools.filter { it.date >= today }))
    }

    Box(modifier.fillMaxSize()) {
        Column(
            Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            Text(greeting(profile?.name.orEmpty()), style = MaterialTheme.typography.headlineSmall)

            // Score card
            SectionCard {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text("Today's score · ${score?.label ?: ""}", style = MaterialTheme.typography.titleSmall)
                    val band = score?.band
                    Text(
                        score?.score?.let { "${band?.label} · $it" } ?: "No data yet",
                        style = MaterialTheme.typography.labelMedium,
                        color = band?.let { bandTextColor(it) } ?: MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier
                            .background((band?.let { Brand.bandColor(it) } ?: Brand.Teal).copy(alpha = 0.15f),
                                RoundedCornerShape(50))
                            .padding(horizontal = 10.dp, vertical = 3.dp),
                    )
                }
                Text("For discussion with your care team — not a diagnosis",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
            }

            // Quick log
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedButton(onClick = {
                    scope.launch { dao.insert(HydrationEntry()) }
                }, modifier = Modifier.weight(1f)) { Text("💧 Water") }
                OutlinedButton(onClick = { showMealSheet = true }, modifier = Modifier.weight(1f)) { Text("🍽 Meal") }
                OutlinedButton(onClick = { showSymptomLog = true }, modifier = Modifier.weight(1f)) { Text("📋 Log") }
            }

            // Bristol quick-tap
            SectionCard {
                Text("Bristol quick-tap", style = MaterialTheme.typography.titleSmall)
                Row(Modifier.fillMaxWidth().padding(top = 6.dp), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    (1..7).forEach { n ->
                        val selected = bristolPick == n
                        Box(
                            Modifier
                                .weight(1f)
                                .height(38.dp)
                                .background(
                                    if (selected) Brand.TealDark else MaterialTheme.colorScheme.surfaceVariant,
                                    RoundedCornerShape(8.dp))
                                .clickable { bristolPick = n },
                            contentAlignment = Alignment.Center,
                        ) {
                            Text("$n", color = if (selected) androidx.compose.ui.graphics.Color.White
                                               else MaterialTheme.colorScheme.onSurface)
                        }
                    }
                }
                if (bristolPick != null) {
                    Row(Modifier.padding(top = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalAlignment = Alignment.CenterVertically) {
                        FilterChip(selected = bmBlood, onClick = { bmBlood = !bmBlood }, label = { Text("Blood") })
                        FilterChip(selected = bmUrgency > 0,
                            onClick = { bmUrgency = (bmUrgency + 1) % 4 },
                            label = { Text(listOf("No urgency", "Hurry", "Immediately", "Accident")[bmUrgency]) })
                        Button(onClick = {
                            val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
                            scope.launch {
                                dao.insert(BowelMovementEntry(bristol = bristolPick ?: 4, blood = bmBlood,
                                    urgency = bmUrgency, nighttime = hour < 6 || hour >= 22))
                            }
                            bristolPick = null; bmBlood = false; bmUrgency = 0
                        }) { Text("Save") }
                    }
                }
            }

            // Next appointment
            appointments.firstOrNull { it.date >= System.currentTimeMillis() }?.let { appt ->
                SectionCard {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                        Column {
                            Text("Next: ${appt.type.label}", style = MaterialTheme.typography.titleSmall)
                            Text(formatDate(appt.date), style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        val open = questions.count { !it.asked }
                        if (open > 0) Text("$open questions", style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.primary)
                    }
                }
            }

            // Meds due
            val nowMinutes = Calendar.getInstance().let { it.get(Calendar.HOUR_OF_DAY) * 60 + it.get(Calendar.MINUTE) }
            val takenToday = doses.filter { it.scheduledAt >= today }
                .map { d ->
                    val c = Calendar.getInstance(); c.timeInMillis = d.scheduledAt
                    "${d.medicationID}-${c.get(Calendar.HOUR_OF_DAY) * 60}"
                }.toSet()
            val due = meds.filter { it.active }
                .flatMap { med -> med.times.map { med to it } }
                .filter { (med, m) -> m <= nowMinutes + 60 && "${med.id}-${(m / 60) * 60}" !in takenToday }
                .minByOrNull { it.second }
            due?.let { (med, minutes) ->
                SectionCard {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text("Meds due", style = MaterialTheme.typography.titleSmall)
                            Text("${med.name} ${med.dose} · ${minutesLabel(minutes)}",
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        Button(onClick = { scope.launch { recordDose(dao, med.id, minutes, "taken") } }) { Text("Taken") }
                    }
                }
            }
        }

        FloatingActionButton(
            onClick = { showSymptomLog = true },
            modifier = Modifier.align(Alignment.BottomEnd).padding(20.dp),
        ) { Icon(Icons.Default.Add, contentDescription = "Log symptoms") }
    }

    if (showSymptomLog) {
        ModalBottomSheet(onDismissRequest = { showSymptomLog = false }) {
            SymptomLogSheet(dao) { showSymptomLog = false }
        }
    }
    if (showMealSheet) {
        ModalBottomSheet(onDismissRequest = { showMealSheet = false }) {
            QuickMealSheet(dao) { showMealSheet = false }
        }
    }
}

private fun greeting(name: String): String {
    val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
    val base = if (hour < 12) "Good morning" else if (hour < 17) "Good afternoon" else "Good evening"
    return if (name.isEmpty()) base else "$base, $name"
}

internal suspend fun recordDose(dao: AppDao, medID: String, minutes: Int, status: String) {
    val cal = Calendar.getInstance()
    cal.set(Calendar.HOUR_OF_DAY, minutes / 60); cal.set(Calendar.MINUTE, minutes % 60); cal.set(Calendar.SECOND, 0)
    dao.insert(com.ibdaide.app.data.DoseEvent(medicationID = medID, scheduledAt = cal.timeInMillis, status = status))
    if (status == "taken") {
        dao.med(medID)?.let { med ->
            med.pillsRemaining?.takeIf { it > 0 }?.let { dao.upsert(med.copy(pillsRemaining = it - 1)) }
        }
    }
}

@Composable
fun SymptomLogSheet(dao: AppDao, onDone: () -> Unit) {
    val scope = rememberCoroutineScope()
    var pain by remember { mutableStateOf(-1f) }
    var wellbeing by remember { mutableStateOf(-1) }
    var nausea by remember { mutableStateOf(false) }
    var jointPain by remember { mutableStateOf(false) }
    var skin by remember { mutableStateOf(false) }
    var eyes by remember { mutableStateOf(false) }
    var mouth by remember { mutableStateOf(false) }
    var weight by remember { mutableStateOf("") }
    var sleep by remember { mutableStateOf("") }
    var notes by remember { mutableStateOf("") }

    Column(
        Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).padding(20.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text("Log symptoms", style = MaterialTheme.typography.titleLarge)

        Text("Abdominal pain: ${if (pain < 0) "not logged" else "${pain.toInt()} / 10"}",
            style = MaterialTheme.typography.titleSmall)
        Slider(value = if (pain < 0) 0f else pain, onValueChange = { pain = it }, valueRange = 0f..10f, steps = 9)

        Text("General well-being", style = MaterialTheme.typography.titleSmall)
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            listOf("Very well", "Below par", "Poor", "Very poor", "Terrible").forEachIndexed { i, label ->
                FilterChip(selected = wellbeing == i, onClick = { wellbeing = if (wellbeing == i) -1 else i },
                    label = { Text(label, style = MaterialTheme.typography.labelSmall) })
            }
        }

        listOf<Triple<String, Boolean, (Boolean) -> Unit>>(
            Triple("Nausea", nausea) { nausea = it },
            Triple("Joint pain", jointPain) { jointPain = it },
            Triple("Skin issues", skin) { skin = it },
            Triple("Eye irritation", eyes) { eyes = it },
            Triple("Mouth ulcers", mouth) { mouth = it },
        ).forEach { (label, value, setter) ->
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically) {
                Text(label)
                Switch(checked = value, onCheckedChange = setter)
            }
        }

        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedTextField(value = weight, onValueChange = { weight = it },
                label = { Text("Weight (lbs)") }, modifier = Modifier.weight(1f))
            OutlinedTextField(value = sleep, onValueChange = { sleep = it },
                label = { Text("Sleep (h)") }, modifier = Modifier.weight(1f))
        }
        OutlinedTextField(value = notes, onValueChange = { notes = it },
            label = { Text("Notes") }, modifier = Modifier.fillMaxWidth())

        Button(onClick = {
            scope.launch {
                dao.insert(SymptomEntry(
                    abdominalPain = if (pain < 0) null else pain.toInt(),
                    wellbeing = wellbeing.takeIf { it >= 0 },
                    nausea = nausea, jointPain = jointPain, skinIssues = skin,
                    eyeIssues = eyes, mouthUlcers = mouth,
                    weightLbs = weight.toDoubleOrNull(), sleepHours = sleep.toDoubleOrNull(),
                    notes = notes))
                onDone()
            }
        }, modifier = Modifier.fillMaxWidth()) { Text("Save") }
    }
}

@Composable
fun QuickMealSheet(dao: AppDao, onDone: () -> Unit) {
    val scope = rememberCoroutineScope()
    var name by remember { mutableStateOf("") }
    var caffeine by remember { mutableStateOf(false) }
    var alcohol by remember { mutableStateOf(false) }
    var trigger by remember { mutableStateOf(false) }

    Column(Modifier.fillMaxWidth().padding(20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text("Log meal", style = MaterialTheme.typography.titleLarge)
        OutlinedTextField(value = name, onValueChange = { name = it },
            label = { Text("What did you eat?") }, modifier = Modifier.fillMaxWidth())
        Row(verticalAlignment = Alignment.CenterVertically) {
            Switch(checked = caffeine, onCheckedChange = { caffeine = it }); Text("  Contains caffeine")
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Switch(checked = alcohol, onCheckedChange = { alcohol = it }); Text("  Contains alcohol")
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Switch(checked = trigger, onCheckedChange = { trigger = it }); Text("  Mark as a personal trigger")
        }
        Button(
            onClick = {
                scope.launch {
                    dao.insert(FoodEntry(name = name, caffeine = caffeine, alcohol = alcohol))
                    if (trigger) dao.insert(TriggerFood(name = name))
                    onDone()
                }
            },
            enabled = name.isNotBlank(),
            modifier = Modifier.fillMaxWidth(),
        ) { Text("Save") }
    }
}
