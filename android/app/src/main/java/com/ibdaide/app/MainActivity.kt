package com.ibdaide.app

import android.Manifest
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_WEAK
import androidx.biometric.BiometricManager.Authenticators.DEVICE_CREDENTIAL
import androidx.biometric.BiometricPrompt
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import com.ibdaide.app.data.AppDatabase
import com.ibdaide.app.ui.IBDAideTheme
import com.ibdaide.app.ui.MainScaffold
import com.ibdaide.app.ui.OnboardingScreen

class MainActivity : FragmentActivity() {

    private val locked = mutableStateOf(false)
    private var lockEnabled = false
    private var initialLockDone = false

    private val notifPermission =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) {}

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // FR-13: no health data in screenshots / recents thumbnail
        window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)

        val dao = AppDatabase.get(this).dao()

        setContent {
            IBDAideTheme {
                val profile by dao.profileFlow().collectAsState(initial = null)
                lockEnabled = profile?.appLockEnabled == true

                // Lock on cold start once we know the setting.
                androidx.compose.runtime.LaunchedEffect(profile?.appLockEnabled) {
                    if (!initialLockDone && profile?.appLockEnabled == true && profile?.onboarded == true) {
                        initialLockDone = true
                        locked.value = true
                        authenticate()
                    }
                }

                Surface(Modifier.fillMaxSize(), color = MaterialTheme.colorScheme.background) {
                    when {
                        locked.value -> LockScreen(onUnlock = { authenticate() })
                        profile?.onboarded == true -> MainScaffold(dao)
                        else -> OnboardingScreen(dao) { requestNotifications() }
                    }
                }
            }
        }
    }

    override fun onStart() {
        super.onStart()
        if (lockEnabled && locked.value) authenticate()
    }

    override fun onStop() {
        super.onStop()
        if (lockEnabled) locked.value = true
    }

    override fun onResume() {
        super.onResume()
        if (lockEnabled && locked.value) authenticate()
    }

    private fun requestNotifications() {
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) !=
            android.content.pm.PackageManager.PERMISSION_GRANTED
        ) {
            notifPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }

    private var authInProgress = false

    private fun authenticate() {
        if (authInProgress) return
        val authenticators = BIOMETRIC_WEAK or DEVICE_CREDENTIAL
        val canAuth = BiometricManager.from(this).canAuthenticate(authenticators)
        if (canAuth != BiometricManager.BIOMETRIC_SUCCESS) {
            // No secure lock on the device — cannot protect; unlock rather than brick the app.
            locked.value = false
            return
        }
        authInProgress = true
        val prompt = BiometricPrompt(this, ContextCompat.getMainExecutor(this),
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    authInProgress = false
                    locked.value = false
                }
                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    authInProgress = false
                }
            })
        val info = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Unlock IBD Aide")
            .setSubtitle("Your health data is protected")
            .setAllowedAuthenticators(authenticators)
            .build()
        prompt.authenticate(info)
    }
}

@androidx.compose.runtime.Composable
private fun LockScreen(onUnlock: () -> Unit) {
    Column(
        Modifier.fillMaxSize().padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Icon(Icons.Default.Lock, contentDescription = null,
            tint = MaterialTheme.colorScheme.primary,
            modifier = Modifier.padding(bottom = 16.dp))
        Text("IBD Aide is locked", style = MaterialTheme.typography.headlineSmall)
        Button(onClick = onUnlock, modifier = Modifier.padding(top = 20.dp)) {
            Text("Unlock")
        }
    }
}
