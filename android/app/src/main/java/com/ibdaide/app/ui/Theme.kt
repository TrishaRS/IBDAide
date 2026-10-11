package com.ibdaide.app.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import com.ibdaide.app.core.ScoreBand
import com.ibdaide.app.core.Verdict

object Brand {
    /// Chart/decorative teal (3:1 graphics contrast is sufficient for non-text).
    val Teal = Color(0xFF2E8B84)
    /// Interactive/text teal — 6.8:1 on white (WCAG AA).
    val TealDark = Color(0xFF1E6560)
    val TealSoft = Color(0xFFDCEEEC)
    // Fill colors for chips (used at low alpha behind text)
    val Green = Color(0xFF3A9D6E)
    val Amber = Color(0xFFD99A2B)
    val Red = Color(0xFFC05B5B)

    fun bandColor(band: ScoreBand): Color = when (band) {
        ScoreBand.REMISSION -> Green
        ScoreBand.MILD -> Amber
        ScoreBand.MODERATE -> Color(0xFFE07B39)
        ScoreBand.SEVERE -> Red
        ScoreBand.UNKNOWN -> Color.Gray
    }

    fun verdictColor(v: Verdict): Color = when (v) {
        Verdict.GREEN -> Green
        Verdict.CAUTION -> Amber
        Verdict.AVOID -> Red
    }
}

// Accessible semantic TEXT colors (≥4.5:1), adaptive for dark mode.
@Composable fun greenText() = if (isSystemInDarkTheme()) Color(0xFF8CD9A6) else Color(0xFF1A7345)
@Composable fun amberText() = if (isSystemInDarkTheme()) Color(0xFFF2C05C) else Color(0xFF8A5A0D)
@Composable fun redText() = if (isSystemInDarkTheme()) Color(0xFFF08C8C) else Color(0xFFA03333)

@Composable fun verdictTextColor(v: Verdict): Color = when (v) {
    Verdict.GREEN -> greenText()
    Verdict.CAUTION -> amberText()
    Verdict.AVOID -> redText()
}

@Composable fun bandTextColor(band: ScoreBand): Color = when (band) {
    ScoreBand.REMISSION -> greenText()
    ScoreBand.MILD, ScoreBand.MODERATE -> amberText()
    ScoreBand.SEVERE -> redText()
    ScoreBand.UNKNOWN -> Color(0xFF5B6673)
}

const val DISCLAIMER =
    "IBD Aide is a tracking tool, not a medical device. It does not provide medical advice, " +
    "diagnosis, or treatment. Food safety results are informational estimates and can be wrong " +
    "or incomplete. Always consult your healthcare team before making changes to diet, " +
    "medication, or treatment. If you have severe symptoms, seek medical care immediately."

@Composable
fun IBDAideTheme(content: @Composable () -> Unit) {
    val dark = isSystemInDarkTheme()
    val scheme = if (dark) darkColorScheme(
        primary = Color(0xFF6FBDB6),
        secondary = Brand.TealSoft,
        primaryContainer = Brand.TealDark,
    ) else lightColorScheme(
        primary = Brand.TealDark,        // accessible interactive/text teal (was Brand.Teal, 4.0:1)
        secondary = Brand.Teal,
        primaryContainer = Brand.TealSoft,
    )
    MaterialTheme(colorScheme = scheme, content = content)
}
