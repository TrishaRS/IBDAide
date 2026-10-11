package com.ibdaide.app.ui

import android.content.Intent
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.FilterChip
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
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.core.content.FileProvider
import com.ibdaide.app.core.Analytics
import com.ibdaide.app.core.ExportManager
import com.ibdaide.app.core.NewsFeedService
import com.ibdaide.app.core.PdfReportBuilder
import com.ibdaide.app.core.ReportData
import com.ibdaide.app.data.AppDao
import com.ibdaide.app.data.Diagnosis
import com.ibdaide.app.data.QoLCheckin
import com.ibdaide.app.data.TriggerFood
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.util.Calendar

@Composable
fun MoreScreen(dao: AppDao, modifier: Modifier = Modifier) {
    var screen by remember { mutableStateOf("menu") }

    when (screen) {
        "report" -> SubScreen("Doctor report", { screen = "menu" }) { ReportSection(dao) }
        "news" -> SubScreen("Treatment news", { screen = "menu" }) { NewsSection(dao) }
        "qol" -> SubScreen("QoL check-in", { screen = "menu" }) { QoLSection(dao) { screen = "menu" } }
        "settings" -> SubScreen("Settings", { screen = "menu" }) { SettingsSection(dao) }
        else -> Column(modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("More", style = MaterialTheme.typography.headlineSmall)
            val context = LocalContext.current
            listOf(
                "📄 Doctor report (PDF)" to "report",
                "📝 Quality-of-life check-in" to "qol",
                "📰 Treatment news" to "news",
                "📍 Restroom finder" to "restroom",
                "⚙️ Settings, backup & privacy" to "settings",
            ).forEach { (label, dest) ->
                SectionCard(Modifier.clickable {
                    if (dest == "restroom") {
                        // FR-11: transient map search — no location stored, no Maps SDK/API key
                        context.startActivity(Intent(Intent.ACTION_VIEW,
                            Uri.parse("geo:0,0?q=" + Uri.encode("public restroom near me"))))
                    } else screen = dest
                }) { Text(label, style = MaterialTheme.typography.titleMedium) }
            }
            Text(DISCLAIMER, style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
}

@Composable
private fun SubScreen(title: String, onBack: () -> Unit, content: @Composable () -> Unit) {
    Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            TextButton(onClick = onBack) { Text("← Back") }
            Text(title, style = MaterialTheme.typography.headlineSmall)
        }
        content()
    }
}

// MARK: Doctor report (FR-9)

@Composable
private fun ReportSection(dao: AppDao) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var rangeDays by remember { mutableIntStateOf(30) }
    var includeQoL by remember { mutableStateOf(true) }
    var status by remember { mutableStateOf<String?>(null) }

    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        listOf(14 to "2 weeks", 30 to "30 days", 90 to "90 days").forEach { (d, label) ->
            FilterChip(selected = rangeDays == d, onClick = { rangeDays = d }, label = { Text(label) })
        }
    }
    Row(verticalAlignment = Alignment.CenterVertically) {
        Switch(checked = includeQoL, onCheckedChange = { includeQoL = it })
        Text("  Include QoL check-ins")
    }
    Button(onClick = {
        scope.launch {
            status = "Generating…"
            val pdf = withContext(Dispatchers.IO) {
                val profile = dao.profile()
                val end = System.currentTimeMillis()
                val start = end - rangeDays * 86_400_000L
                val diagnosis = profile?.diagnosis ?: Diagnosis.CROHNS
                val symptoms = dao.symptoms()
                val stools = dao.bms()
                val scores = Analytics.dailyScores(diagnosis, symptoms, stools, start, end)
                val periodStools = stools.filter { it.date >= start }
                val bloodDays = periodStools.filter { it.blood }.map { it.date / 86_400_000L }.toSet().size
                val pains = symptoms.filter { it.date >= start }.mapNotNull { it.abdominalPain }
                PdfReportBuilder.makePdf(ReportData(
                    patientName = profile?.name ?: "",
                    diagnosis = diagnosis.label,
                    scoreLabel = when (diagnosis) {
                        Diagnosis.CROHNS -> "Modified HBI"
                        Diagnosis.ULCERATIVE_COLITIS -> "Modified SCCAI"
                        else -> "Symptom burden"
                    },
                    startDate = start, endDate = end,
                    dailyScores = scores.map { it.day to it.score },
                    totalBMs = periodStools.size, bloodDays = bloodDays,
                    avgPain = if (pains.isEmpty()) null else pains.sum().toDouble() / pains.size,
                    adherencePercent = Analytics.adherencePercent(dao.meds(), dao.doses(), start, end),
                    triggers = dao.triggers().map { it.name },
                    questions = dao.questions().filter { !it.asked }.map { it.text },
                    qolTotals = dao.qol().map { it.date to it.total },
                    includeQoL = includeQoL,
                ))
            }
            val dir = File(context.cacheDir, "reports").apply { mkdirs() }
            val file = File(dir, "IBD-Aide-Report.pdf")
            file.writeBytes(pdf)
            val uri = FileProvider.getUriForFile(context, "${context.packageName}.files", file)
            val send = Intent(Intent.ACTION_SEND).apply {
                type = "application/pdf"
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            context.startActivity(Intent.createChooser(send, "Share report"))
            status = null
        }
    }, modifier = Modifier.fillMaxWidth()) { Text("Generate & share PDF…") }
    status?.let { Text(it, style = MaterialTheme.typography.bodySmall) }
    Text("Opens your share sheet (Gmail, Messages…). IBD Aide never sends your data itself.",
        style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
}

// MARK: News (FR-10)

@Composable
private fun NewsSection(dao: AppDao) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val news by dao.newsFlow().collectAsState(initial = emptyList())
    var refreshing by remember { mutableStateOf(false) }

    OutlinedButton(onClick = {
        scope.launch { refreshing = true; NewsFeedService.refresh(dao); refreshing = false }
    }, enabled = !refreshing, modifier = Modifier.fillMaxWidth()) {
        Text(if (refreshing) "Refreshing…" else "Refresh")
    }
    Text("Curated updates on IBD treatment advancements. Always discuss findings with your care team before acting on them.",
        style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    news.take(50).forEach { item ->
        SectionCard(Modifier.clickable {
            scope.launch { dao.update(item.copy(isRead = true)) }
            runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(item.link))) }
        }) {
            Text(item.title, style = if (item.isRead) MaterialTheme.typography.bodyMedium
                                     else MaterialTheme.typography.titleSmall)
            Text("${item.source} · ${formatDay(item.publishedAt)}",
                style = MaterialTheme.typography.labelSmall, color = MaterialTheme.colorScheme.primary)
            if (item.summary.isNotEmpty()) Text(item.summary, style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant, maxLines = 3)
        }
    }
}

// MARK: QoL (FR-12)

@Composable
private fun QoLSection(dao: AppDao, onDone: () -> Unit) {
    val scope = rememberCoroutineScope()
    var answers by remember { mutableStateOf(List(QoLCheckin.QUESTIONS.size) { 2 }) }

    Text("Thinking about the last two weeks, how much do you agree? (0 = not at all, 4 = completely)",
        style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    QoLCheckin.QUESTIONS.forEachIndexed { i, q ->
        SectionCard {
            Text(q, style = MaterialTheme.typography.bodyMedium)
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                (0..4).forEach { v ->
                    FilterChip(selected = answers[i] == v,
                        onClick = { answers = answers.toMutableList().also { it[i] = v } },
                        label = { Text("$v") })
                }
            }
        }
    }
    Button(onClick = {
        scope.launch {
            dao.insert(QoLCheckin(answers = answers.joinToString(","), total = answers.sum()))
            onDone()
        }
    }, modifier = Modifier.fillMaxWidth()) { Text("Save check-in (${answers.sum()}/32)") }
}

// MARK: Settings (FR-13/FR-14)

@Composable
private fun SettingsSection(dao: AppDao) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val profile by dao.profileFlow().collectAsState(initial = null)
    val triggers by dao.triggersFlow().collectAsState(initial = emptyList())

    var newTrigger by remember { mutableStateOf("") }
    var status by remember { mutableStateOf<String?>(null) }
    var passphrase by remember { mutableStateOf("") }
    var askExportPass by remember { mutableStateOf(false) }
    var askImportPass by remember { mutableStateOf(false) }
    var pendingExport by remember { mutableStateOf<ByteArray?>(null) }
    var pendingImport by remember { mutableStateOf<ByteArray?>(null) }
    var confirmDelete by remember { mutableStateOf(false) }

    val exportLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.CreateDocument("application/octet-stream")) { uri ->
        val data = pendingExport
        if (uri != null && data != null) {
            context.contentResolver.openOutputStream(uri)?.use { it.write(data) }
            status = "Backup exported."
        }
        pendingExport = null
    }
    val importLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.OpenDocument()) { uri ->
        uri?.let {
            pendingImport = context.contentResolver.openInputStream(it)?.use { s -> s.readBytes() }
            if (pendingImport != null) askImportPass = true else status = "Couldn't read that file."
        }
    }

    profile?.let { p ->
        SectionCard {
            Text("Security", style = MaterialTheme.typography.titleSmall)
            Row(verticalAlignment = Alignment.CenterVertically) {
                Switch(checked = p.appLockEnabled, onCheckedChange = {
                    scope.launch { dao.upsertProfile(p.copy(appLockEnabled = it)) }
                })
                Text("  Require fingerprint/face to open")
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Switch(checked = p.flareMode, onCheckedChange = {
                    scope.launch { dao.upsertProfile(p.copy(flareMode = it)) }
                })
                Text("  Flare mode (stricter food rules)")
            }
            Text("Data is stored only on this phone, protected by Android's file-based encryption, and included in your end-to-end-encrypted device backup.",
                style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }

    SectionCard {
        Text("Personal trigger foods", style = MaterialTheme.typography.titleSmall)
        triggers.forEach { t ->
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically) {
                Text(t.name)
                TextButton(onClick = { scope.launch { dao.delete(t) } }) { Text("✕") }
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedTextField(value = newTrigger, onValueChange = { newTrigger = it },
                label = { Text("Add trigger food…") }, modifier = Modifier.weight(1f))
            TextButton(onClick = {
                scope.launch { dao.insert(TriggerFood(name = newTrigger)); newTrigger = "" }
            }, enabled = newTrigger.isNotBlank()) { Text("Add") }
        }
    }

    SectionCard {
        Text("Backup & device migration", style = MaterialTheme.typography.titleSmall)
        Text("Your data survives phone upgrades through Android's encrypted device backup (and Samsung Smart Switch). You can also make a portable encrypted backup file:",
            style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        OutlinedButton(onClick = { askExportPass = true }, modifier = Modifier.fillMaxWidth()) {
            Text("Export encrypted backup…")
        }
        OutlinedButton(onClick = { importLauncher.launch(arrayOf("*/*")) }, modifier = Modifier.fillMaxWidth()) {
            Text("Restore from backup…")
        }
        status?.let { Text(it, style = MaterialTheme.typography.bodySmall) }
    }

    SectionCard {
        Text("About & privacy", style = MaterialTheme.typography.titleSmall)
        Text("Version 1.0 · Free. No ads. No accounts. No analytics. Your health data never leaves this phone — the only network requests are barcode/food lookups (no identity), news feeds, and map search.",
            style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }

    OutlinedButton(onClick = { confirmDelete = true }, modifier = Modifier.fillMaxWidth()) {
        Text("Delete all data", color = Brand.Red)
    }

    if (askExportPass || askImportPass) {
        AlertDialog(
            onDismissRequest = { askExportPass = false; askImportPass = false; passphrase = "" },
            title = { Text(if (askExportPass) "Choose a backup passphrase" else "Backup passphrase") },
            text = {
                Column {
                    if (askExportPass) Text("You'll need this passphrase to restore. It cannot be recovered.",
                        style = MaterialTheme.typography.bodySmall)
                    else Text("Restoring replaces ALL current data.", style = MaterialTheme.typography.bodySmall)
                    OutlinedTextField(value = passphrase, onValueChange = { passphrase = it },
                        label = { Text("Passphrase") }, visualTransformation = PasswordVisualTransformation())
                }
            },
            confirmButton = {
                Button(onClick = {
                    val pass = passphrase
                    val isExport = askExportPass
                    askExportPass = false; askImportPass = false; passphrase = ""
                    scope.launch {
                        try {
                            if (isExport) {
                                if (pass.length < 6) { status = "Use a passphrase of at least 6 characters."; return@launch }
                                status = "Encrypting…"
                                pendingExport = withContext(Dispatchers.Default) {
                                    ExportManager.encrypt(ExportManager.buildEnvelope(dao), pass)
                                }
                                exportLauncher.launch("IBD-Aide-Backup.ibdaide")
                                status = null
                            } else {
                                val data = pendingImport ?: return@launch
                                status = "Restoring…"
                                val env = withContext(Dispatchers.Default) { ExportManager.decrypt(data, pass) }
                                ExportManager.apply(env, dao)
                                status = "Backup restored."
                                pendingImport = null
                            }
                        } catch (e: Exception) {
                            status = e.message
                        }
                    }
                }, enabled = passphrase.isNotEmpty()) { Text(if (askExportPass) "Export" else "Restore") }
            },
            dismissButton = {
                TextButton(onClick = { askExportPass = false; askImportPass = false; passphrase = "" }) { Text("Cancel") }
            },
        )
    }

    if (confirmDelete) {
        AlertDialog(
            onDismissRequest = { confirmDelete = false },
            title = { Text("Delete all data?") },
            text = { Text("This permanently erases everything in IBD Aide. It cannot be undone.") },
            confirmButton = {
                Button(onClick = {
                    scope.launch { dao.wipeAll(); confirmDelete = false }
                }) { Text("Delete everything", color = Brand.Red) }
            },
            dismissButton = { TextButton(onClick = { confirmDelete = false }) { Text("Cancel") } },
        )
    }
}
