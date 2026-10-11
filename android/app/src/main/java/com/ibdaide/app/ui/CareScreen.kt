package com.ibdaide.app.ui

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.RadioButtonUnchecked
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Checkbox
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
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
import com.ibdaide.app.core.Reminders
import com.ibdaide.app.data.AppDao
import com.ibdaide.app.data.Appointment
import com.ibdaide.app.data.AppointmentType
import com.ibdaide.app.data.Provider
import com.ibdaide.app.data.ProviderRole
import com.ibdaide.app.data.VisitQuestion
import kotlinx.coroutines.launch
import java.util.Calendar

@Composable
fun CareScreen(dao: AppDao, modifier: Modifier = Modifier) {
    var segment by remember { mutableIntStateOf(0) }
    Column(modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text("Care", style = MaterialTheme.typography.headlineSmall)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf("Appointments", "Care team", "Meds").forEachIndexed { i, label ->
                FilterChip(selected = segment == i, onClick = { segment = i }, label = { Text(label) })
            }
        }
        when (segment) {
            0 -> AppointmentsSection(dao)
            1 -> ProvidersSection(dao)
            else -> MedsSection(dao)
        }
    }
}

// MARK: Appointments (FR-7)

@Composable
private fun AppointmentsSection(dao: AppDao) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val appointments by dao.appointmentsFlow().collectAsState(initial = emptyList())
    val providers by dao.providersFlow().collectAsState(initial = emptyList())
    val questions by dao.questionsFlow().collectAsState(initial = emptyList())

    var newQuestion by remember { mutableStateOf("") }
    var editing by remember { mutableStateOf<Appointment?>(null) }
    var showNew by remember { mutableStateOf(false) }

    Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(10.dp)) {

        SectionCard {
            Text("Questions to ask at my next visit", style = MaterialTheme.typography.titleSmall)
            questions.filter { !it.asked }.forEach { q ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    IconButton(onClick = { scope.launch { dao.upsert(q.copy(asked = true)) } }) {
                        Icon(Icons.Default.RadioButtonUnchecked, contentDescription = "Mark asked")
                    }
                    Text(q.text, Modifier.weight(1f))
                    TextButton(onClick = { scope.launch { dao.delete(q) } }) { Text("✕") }
                }
            }
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(value = newQuestion, onValueChange = { newQuestion = it },
                    label = { Text("Add a question…") }, modifier = Modifier.weight(1f))
                IconButton(onClick = {
                    scope.launch { dao.upsert(VisitQuestion(text = newQuestion)); newQuestion = "" }
                }, enabled = newQuestion.isNotBlank()) { Icon(Icons.Default.Add, contentDescription = "Add") }
            }
        }

        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically) {
            Text("Upcoming", style = MaterialTheme.typography.titleSmall)
            Button(onClick = { showNew = true }) { Text("＋ Add") }
        }
        val upcoming = appointments.filter { it.date >= System.currentTimeMillis() - 3_600_000L }
        if (upcoming.isEmpty()) Text("No upcoming appointments.",
            style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        upcoming.forEach { appt ->
            SectionCard(Modifier.clickable { editing = appt }) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                    Text(appt.type.label, style = MaterialTheme.typography.titleSmall)
                    appt.recurringWeeks?.let { Text("every $it wks", style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary) }
                }
                Text(formatDate(appt.date), style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
                providers.firstOrNull { it.id == appt.providerID }?.let {
                    Text(it.name, style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                if (appt.type == AppointmentType.PROCEDURE) {
                    Text("Prep: ${appt.prepDoneSet.size}/${Appointment.PREP_CHECKLIST.size} done",
                        style = MaterialTheme.typography.labelSmall,
                        color = if (appt.prepDoneSet.size == Appointment.PREP_CHECKLIST.size) Brand.Green else Brand.Amber)
                }
            }
        }

        val past = appointments.filter { it.date < System.currentTimeMillis() - 3_600_000L }.reversed().take(5)
        if (past.isNotEmpty()) {
            Text("Past", style = MaterialTheme.typography.titleSmall)
            past.forEach { appt ->
                SectionCard(Modifier.clickable { editing = appt }) {
                    Text("${appt.type.label} · ${formatDate(appt.date)}", style = MaterialTheme.typography.bodySmall)
                }
            }
        }
    }

    if (showNew) AppointmentEditDialog(dao, null, providers) { showNew = false }
    editing?.let { appt -> AppointmentEditDialog(dao, appt, providers) { editing = null } }
}

@Composable
private fun AppointmentEditDialog(dao: AppDao, appointment: Appointment?,
                                  providers: List<Provider>, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var type by remember { mutableStateOf(appointment?.type ?: AppointmentType.OFFICE_VISIT) }
    var dateMillis by remember { mutableStateOf(appointment?.date ?: (System.currentTimeMillis() + 86_400_000L)) }
    var providerID by remember { mutableStateOf(appointment?.providerID) }
    var recurring by remember { mutableStateOf(appointment?.recurringWeeks != null) }
    var weeks by remember { mutableIntStateOf(appointment?.recurringWeeks ?: 8) }
    var prepDone by remember { mutableStateOf(appointment?.prepDoneSet ?: emptySet()) }
    var notes by remember { mutableStateOf(appointment?.preVisitNotes ?: "") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (appointment == null) "New appointment" else "Edit appointment") },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(Modifier.horizontalScrollRow(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    AppointmentType.entries.forEach { t ->
                        FilterChip(selected = type == t, onClick = { type = t },
                            label = { Text(t.label, style = MaterialTheme.typography.labelSmall) })
                    }
                }
                // Simple date/time entry (v1): tap chips to adjust
                Text("When: ${formatDate(dateMillis)}", style = MaterialTheme.typography.bodyMedium)
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    listOf("-1d" to -86_400_000L, "+1d" to 86_400_000L, "-1h" to -3_600_000L, "+1h" to 3_600_000L)
                        .forEach { (label, delta) ->
                            FilterChip(selected = false, onClick = { dateMillis += delta }, label = { Text(label) })
                        }
                }
                if (providers.isNotEmpty()) {
                    Text("Provider", style = MaterialTheme.typography.titleSmall)
                    Row(Modifier.horizontalScrollRow(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        providers.forEach { p ->
                            FilterChip(selected = providerID == p.id,
                                onClick = { providerID = if (providerID == p.id) null else p.id },
                                label = { Text(p.name, style = MaterialTheme.typography.labelSmall) })
                        }
                    }
                }
                if (type == AppointmentType.INFUSION) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Switch(checked = recurring, onCheckedChange = { recurring = it })
                        Text("  Repeats every ")
                        FilterChip(selected = false, onClick = { if (weeks > 1) weeks-- }, label = { Text("−") })
                        Text(" $weeks wks ")
                        FilterChip(selected = false, onClick = { if (weeks < 16) weeks++ }, label = { Text("＋") })
                    }
                }
                if (type == AppointmentType.PROCEDURE) {
                    Text("Colonoscopy prep checklist", style = MaterialTheme.typography.titleSmall)
                    Appointment.PREP_CHECKLIST.forEach { item ->
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Checkbox(checked = item in prepDone, onCheckedChange = {
                                prepDone = if (item in prepDone) prepDone - item else prepDone + item
                            })
                            Text(item, style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }
                OutlinedTextField(value = notes, onValueChange = { notes = it },
                    label = { Text("Notes") }, modifier = Modifier.fillMaxWidth())
                Text("Reminders: 1 week, 1 day, and 2 hours before.",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        },
        confirmButton = {
            Button(onClick = {
                scope.launch {
                    val a = (appointment ?: Appointment()).copy(
                        typeRaw = type.label, date = dateMillis, providerID = providerID,
                        recurringWeeks = if (type == AppointmentType.INFUSION && recurring) weeks else null,
                        preVisitNotes = notes, prepDone = prepDone.joinToString("\n"))
                    dao.upsert(a)
                    Reminders.scheduleAppointmentReminders(context, a)
                    onDismiss()
                }
            }) { Text("Save") }
        },
        dismissButton = {
            Row {
                if (appointment != null) TextButton(onClick = {
                    scope.launch {
                        Reminders.cancelAppointmentReminders(context, appointment)
                        dao.delete(appointment); onDismiss()
                    }
                }) { Text("Delete", color = Brand.Red) }
                TextButton(onClick = onDismiss) { Text("Cancel") }
            }
        },
    )
}

// MARK: Providers (FR-6)

@Composable
private fun ProvidersSection(dao: AppDao) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val providers by dao.providersFlow().collectAsState(initial = emptyList())
    var editing by remember { mutableStateOf<Provider?>(null) }
    var showNew by remember { mutableStateOf(false) }

    Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Button(onClick = { showNew = true }) { Text("＋ Add contact") }
        if (providers.isEmpty()) Text("Add your GI doctor, nurse line, infusion center, and pharmacy.",
            style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        providers.forEach { p ->
            SectionCard(Modifier.clickable { editing = p }) {
                Text(p.name, style = MaterialTheme.typography.titleSmall)
                Text(p.role.label, style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    if (p.phone.isNotEmpty()) TextButton(onClick = {
                        context.startActivity(Intent(Intent.ACTION_DIAL,
                            Uri.parse("tel:" + p.phone.filter { it.isDigit() || it == '+' })))
                    }) { Text("Call") }
                    if (p.email.isNotEmpty()) TextButton(onClick = {
                        context.startActivity(Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:${p.email}")))
                    }) { Text("Email") }
                    if (p.address.isNotEmpty()) TextButton(onClick = {
                        context.startActivity(Intent(Intent.ACTION_VIEW,
                            Uri.parse("geo:0,0?q=" + Uri.encode(p.address))))
                    }) { Text("Map") }
                }
            }
        }
    }

    if (showNew) ProviderEditDialog(dao, null) { showNew = false }
    editing?.let { p -> ProviderEditDialog(dao, p) { editing = null } }
}

@Composable
private fun ProviderEditDialog(dao: AppDao, provider: Provider?, onDismiss: () -> Unit) {
    val scope = rememberCoroutineScope()
    var name by remember { mutableStateOf(provider?.name ?: "") }
    var role by remember { mutableStateOf(provider?.role ?: ProviderRole.GI_DOCTOR) }
    var phone by remember { mutableStateOf(provider?.phone ?: "") }
    var email by remember { mutableStateOf(provider?.email ?: "") }
    var address by remember { mutableStateOf(provider?.address ?: "") }
    var notes by remember { mutableStateOf(provider?.notes ?: "") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (provider == null) "New contact" else "Edit contact") },
        text = {
            Column(Modifier.verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(value = name, onValueChange = { name = it }, label = { Text("Name") })
                Row(Modifier.horizontalScrollRow(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    ProviderRole.entries.forEach { r ->
                        FilterChip(selected = role == r, onClick = { role = r },
                            label = { Text(r.label, style = MaterialTheme.typography.labelSmall) })
                    }
                }
                OutlinedTextField(value = phone, onValueChange = { phone = it }, label = { Text("Phone") })
                OutlinedTextField(value = email, onValueChange = { email = it }, label = { Text("Email") })
                OutlinedTextField(value = address, onValueChange = { address = it }, label = { Text("Address") })
                OutlinedTextField(value = notes, onValueChange = { notes = it }, label = { Text("Notes") })
            }
        },
        confirmButton = {
            Button(onClick = {
                scope.launch {
                    dao.upsert((provider ?: Provider()).copy(name = name, roleRaw = role.label,
                        phone = phone, email = email, address = address, notes = notes))
                    onDismiss()
                }
            }, enabled = name.isNotBlank()) { Text("Save") }
        },
        dismissButton = {
            Row {
                if (provider != null) TextButton(onClick = {
                    scope.launch { dao.delete(provider); onDismiss() }
                }) { Text("Delete", color = Brand.Red) }
                TextButton(onClick = onDismiss) { Text("Cancel") }
            }
        },
    )
}

// Helper: horizontally scrollable chip row
@Composable
private fun Modifier.horizontalScrollRow(): Modifier =
    this.horizontalScroll(rememberScrollState())
