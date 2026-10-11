package com.ibdaide.app.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.ibdaide.app.data.AppDao
import com.ibdaide.app.data.Diagnosis
import com.ibdaide.app.data.UserProfile
import kotlinx.coroutines.launch

@Composable
fun OnboardingScreen(dao: AppDao, onDone: () -> Unit) {
    val scope = rememberCoroutineScope()
    var name by remember { mutableStateOf("") }
    var diagnosis by remember { mutableStateOf(Diagnosis.CROHNS) }
    var enableLock by remember { mutableStateOf(true) }
    var accepted by remember { mutableStateOf(false) }

    Column(
        Modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(24.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Text("Welcome to IBD Aide", style = MaterialTheme.typography.headlineMedium)
        Text(
            "A private companion for Crohn's disease, ulcerative colitis, and IBD-U. " +
            "Your health data stays on this phone — encrypted, behind your fingerprint or face, never sold or shared.",
            style = MaterialTheme.typography.bodyMedium,
        )

        Card {
            Column(Modifier.padding(14.dp)) {
                Text("Please read", style = MaterialTheme.typography.titleSmall)
                Spacer(Modifier.height(6.dp))
                Text(DISCLAIMER, style = MaterialTheme.typography.bodySmall)
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Switch(checked = accepted, onCheckedChange = { accepted = it })
            Text("  I understand — IBD Aide is not medical advice",
                style = MaterialTheme.typography.bodyMedium)
        }

        OutlinedTextField(value = name, onValueChange = { name = it },
            label = { Text("First name (optional)") }, modifier = Modifier.fillMaxWidth())

        Text("Diagnosis", style = MaterialTheme.typography.titleSmall)
        Diagnosis.entries.forEach { d ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                RadioButton(selected = diagnosis == d, onClick = { diagnosis = d })
                Text(d.label)
            }
        }

        Row(verticalAlignment = Alignment.CenterVertically) {
            Switch(checked = enableLock, onCheckedChange = { enableLock = it })
            Text("  Require fingerprint/face to open the app",
                style = MaterialTheme.typography.bodyMedium)
        }

        Button(
            onClick = {
                scope.launch {
                    dao.upsertProfile(UserProfile(
                        name = name, diagnosisRaw = diagnosis.label,
                        onboarded = true, appLockEnabled = enableLock))
                    onDone()
                }
            },
            enabled = accepted,
            modifier = Modifier.fillMaxWidth(),
        ) { Text("Get started") }
    }
}
