package com.ibdaide.app.ui

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.MedicalServices
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.QrCodeScanner
import androidx.compose.material.icons.filled.ShowChart
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import com.ibdaide.app.data.AppDao

@Composable
fun MainScaffold(dao: AppDao) {
    var tab by remember { mutableIntStateOf(0) }
    val tabs = listOf(
        "Home" to Icons.Default.Home,
        "Trends" to Icons.Default.ShowChart,
        "Scan" to Icons.Default.QrCodeScanner,
        "Care" to Icons.Default.MedicalServices,
        "More" to Icons.Default.MoreHoriz,
    )
    Scaffold(
        bottomBar = {
            NavigationBar {
                tabs.forEachIndexed { i, (label, icon) ->
                    NavigationBarItem(
                        selected = tab == i,
                        onClick = { tab = i },
                        icon = { Icon(icon, contentDescription = label) },
                        label = { Text(label) },
                    )
                }
            }
        }
    ) { padding ->
        val modifier = Modifier.padding(padding)
        when (tab) {
            0 -> HomeScreen(dao, modifier)
            1 -> TrendsScreen(dao, modifier)
            2 -> ScanScreen(dao, modifier)
            3 -> CareScreen(dao, modifier)
            else -> MoreScreen(dao, modifier)
        }
    }
}
