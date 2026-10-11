import SwiftUI
import UIKit

/// Color system — tuned for WCAG AA (≥4.5:1 for text, NFR-5) while keeping the
/// calm teal "medical" identity:
/// - `accent` (global tint, interactive text): deep teal — 6.8:1 on white.
///   The original lighter teal failed AA (4.0:1 on white, 3.4:1 on tinted fills).
/// - `chartAccent`: the original brand teal, kept for chart strokes and decorative
///   fills where WCAG's 3:1 graphics threshold applies.
/// - Band/verdict colors come in a fill variant (backgrounds) and a darker
///   text variant (≥4.5:1 on white and on their own 15% tints).
/// - All text colors are adaptive: darker in light mode, brighter in dark mode.
enum Theme {

    /// Interactive/text teal (global tint). Light: #1E6560 · Dark: #7FC4BD
    static let accent = adaptive(light: (0.12, 0.40, 0.38), dark: (0.50, 0.77, 0.74))

    /// Decorative brand teal for charts and fills (3:1 graphics contrast is sufficient).
    static let chartAccent = Color(red: 0.18, green: 0.55, blue: 0.52)

    /// Soft tinted card background. Light: pale teal · Dark: deep muted teal
    static let accentSoft = adaptive(light: (0.86, 0.93, 0.92), dark: (0.09, 0.23, 0.22))

    // MARK: Score bands

    /// Fill color for band chips (used at low opacity behind text).
    static func bandColor(_ band: ScoreBand) -> Color {
        switch band {
        case .remission: return .green
        case .mild: return .yellow
        case .moderate: return .orange
        case .severe: return .red
        case .unknown: return .gray
        }
    }

    /// Text color for band chips — dark enough for AA on the tinted fill.
    static func bandTextColor(_ band: ScoreBand) -> Color {
        switch band {
        case .remission: return greenText
        case .mild, .moderate: return amberText
        case .severe: return redText
        case .unknown: return adaptive(light: (0.35, 0.40, 0.45), dark: (0.70, 0.74, 0.78))
        }
    }

    // MARK: Food verdicts

    /// Fill color for verdict chips (used at low opacity behind text).
    static func verdictColor(_ v: Verdict) -> Color {
        switch v {
        case .green: return .green
        case .caution: return .orange
        case .avoid: return .red
        }
    }

    /// Text color for verdict chips and warning copy.
    static func verdictTextColor(_ v: Verdict) -> Color {
        switch v {
        case .green: return greenText
        case .caution: return amberText
        case .avoid: return redText
        }
    }

    /// Accessible semantic text colors (light / dark variants).
    static let greenText = adaptive(light: (0.10, 0.45, 0.27), dark: (0.55, 0.85, 0.65))
    static let amberText = adaptive(light: (0.54, 0.35, 0.05), dark: (0.95, 0.75, 0.35))
    static let redText   = adaptive(light: (0.63, 0.20, 0.20), dark: (0.95, 0.55, 0.55))

    // MARK: Helper

    private static func adaptive(light: (Double, Double, Double),
                                 dark: (Double, Double, Double)) -> Color {
        Color(UIColor { trait in
            let c = trait.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }
}

extension View {
    func cardStyle() -> some View {
        self
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

let disclaimerText = """
IBD Aide is a tracking tool, not a medical device. It does not provide medical advice, diagnosis, or treatment. Food safety results are informational estimates and can be wrong or incomplete. Always consult your healthcare team before making changes to diet, medication, or treatment. If you have severe symptoms, seek medical care immediately.
"""
