import Foundation
import UIKit

/// FR-9: generates the doctor report PDF entirely on device.
/// The app never transmits it — the user shares via their own Mail/Messages.
struct ReportData {
    var patientName: String
    var diagnosis: String
    var scoreLabel: String
    var startDate: Date
    var endDate: Date
    /// (day, score) sorted ascending; nil scores excluded
    var dailyScores: [(Date, Int)]
    /// preformatted per-day lines, e.g. "Jul 20:  5  (Mild)"
    var scoreLines: [String] = []
    var totalBMs: Int
    var bloodDays: Int
    var avgPain: Double?
    var adherencePercent: Int?
    var triggers: [String]
    var questions: [String]
    var qolTotals: [(Date, Int)]
    var includeQoL: Bool
}

enum PDFReportBuilder {

    static func makePDF(_ r: ReportData) -> Data {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let margin: CGFloat = 48
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let df = DateFormatter(); df.dateStyle = .medium

        return renderer.pdfData { ctx in
            ctx.beginPage()
            var y: CGFloat = margin

            func draw(_ text: String, font: UIFont, color: UIColor = .black, spacing: CGFloat = 6) {
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                let bounds = CGSize(width: pageRect.width - margin * 2, height: .greatestFiniteMagnitude)
                let size = (text as NSString).boundingRect(with: bounds, options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
                if y + size.height > pageRect.height - margin {
                    ctx.beginPage(); y = margin
                }
                (text as NSString).draw(in: CGRect(x: margin, y: y, width: bounds.width, height: size.height), withAttributes: attrs)
                y += size.height + spacing
            }

            // Header
            draw("IBD Aide — Health Summary", font: .boldSystemFont(ofSize: 22))
            draw("\(r.patientName.isEmpty ? "Patient" : r.patientName) · \(r.diagnosis)", font: .systemFont(ofSize: 12), color: .darkGray)
            draw("Period: \(df.string(from: r.startDate)) – \(df.string(from: r.endDate))    Generated: \(df.string(from: Date()))",
                 font: .systemFont(ofSize: 11), color: .darkGray, spacing: 14)

            // Symptom summary
            draw("Symptom summary", font: .boldSystemFont(ofSize: 15))
            let scores = r.dailyScores.map(\.1)
            if scores.isEmpty {
                draw("No symptom or bowel-movement logs recorded in this period, so no daily scores could be computed. Log symptoms on the Home tab to populate this section.",
                     font: .systemFont(ofSize: 12))
            } else {
                let avg = Double(scores.reduce(0, +)) / Double(scores.count)
                draw("\(r.scoreLabel) — average \(String(format: "%.1f", avg)), lowest \(scores.min() ?? 0), highest \(scores.max() ?? 0), across \(scores.count) recorded day\(scores.count == 1 ? "" : "s")",
                     font: .systemFont(ofSize: 12))

                // Score trend chart (page-break BEFORE placing the chart so it can't draw off-page)
                if y + 130 > pageRect.height - margin { ctx.beginPage(); y = margin }
                let chartRect = CGRect(x: margin, y: y, width: pageRect.width - margin * 2, height: 100)
                drawTrendChart(r.dailyScores, in: chartRect)
                y += 116

                // Per-day scores (most recent 31)
                draw("Daily scores:", font: .boldSystemFont(ofSize: 11), spacing: 3)
                for line in r.scoreLines.suffix(31) {
                    draw(line, font: .systemFont(ofSize: 10), spacing: 2)
                }
                y += 8
            }
            draw("Bowel movements: \(r.totalBMs) logged · days with visible blood: \(r.bloodDays)", font: .systemFont(ofSize: 12))
            if let pain = r.avgPain {
                draw("Average abdominal pain: \(String(format: "%.1f", pain)) / 10", font: .systemFont(ofSize: 12), spacing: 14)
            }

            // Adherence
            draw("Medication adherence", font: .boldSystemFont(ofSize: 15))
            if let adherence = r.adherencePercent {
                draw("\(adherence)% of scheduled doses recorded as taken in this period.", font: .systemFont(ofSize: 12), spacing: 14)
            } else {
                draw("No scheduled medications tracked in this period.", font: .systemFont(ofSize: 12), spacing: 14)
            }

            // Triggers
            draw("Food triggers", font: .boldSystemFont(ofSize: 15))
            draw(r.triggers.isEmpty ? "None recorded." : r.triggers.joined(separator: " · "),
                 font: .systemFont(ofSize: 12), spacing: 14)

            // Questions
            draw("Questions for this visit", font: .boldSystemFont(ofSize: 15))
            if r.questions.isEmpty {
                draw("None.", font: .systemFont(ofSize: 12), spacing: 14)
            } else {
                for (i, q) in r.questions.enumerated() {
                    draw("\(i + 1). \(q)", font: .systemFont(ofSize: 12), spacing: 3)
                }
                y += 10
            }

            // QoL
            if r.includeQoL, !r.qolTotals.isEmpty {
                draw("Quality-of-life check-ins (adapted IBD-Control-8; higher = better)", font: .boldSystemFont(ofSize: 15))
                for (date, total) in r.qolTotals.suffix(6) {
                    draw("\(df.string(from: date)): \(total) / 32", font: .systemFont(ofSize: 12), spacing: 3)
                }
                y += 10
            }

            // Disclaimer footer
            draw("Generated by IBD Aide from patient-reported data. Scores are modified, informational adaptations of clinical indices and are not a diagnosis. Not a medical device.",
                 font: .italicSystemFont(ofSize: 9), color: .gray, spacing: 4)
            draw("Score indices adapted from: Harvey & Bradshaw, Lancet 1980 (HBI); Walmsley et al., Gut 1998 (SCCAI); Bodger et al., Gut 2014 (IBD-Control). Dietary guidance: Crohn's & Colitis Foundation, \"What Should I Eat?\"; Levine et al., Clin Gastroenterol Hepatol 2020 (IOIBD). Full citations: IBD Aide ▸ More ▸ Medical sources.",
                 font: .italicSystemFont(ofSize: 8), color: .gray)
        }
    }

    /// Draws the score trend. Works with ANY number of points — a single logged
    /// day renders as a labeled dot (the old version silently skipped n < 2).
    private static func drawTrendChart(_ points: [(Date, Int)], in rect: CGRect) {
        guard !points.isEmpty, let context = UIGraphicsGetCurrentContext() else { return }
        let values = points.map { Double($0.1) }
        let maxV = max(values.max() ?? 1, 1)
        let minV = 0.0
        let range = max(maxV - minV, 1)
        let plot = rect.insetBy(dx: 26, dy: 10)   // leave room for axis labels

        context.saveGState()
        context.setStrokeColor(UIColor.lightGray.cgColor)
        context.setLineWidth(0.5)
        context.stroke(plot.insetBy(dx: 0.25, dy: 0.25))

        // Y-axis labels (max / 0)
        let axisAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8),
                                                        .foregroundColor: UIColor.gray]
        ("\(Int(maxV))" as NSString).draw(at: CGPoint(x: rect.minX, y: plot.minY - 4), withAttributes: axisAttrs)
        ("0" as NSString).draw(at: CGPoint(x: rect.minX + 12, y: plot.maxY - 8), withAttributes: axisAttrs)

        func pointAt(_ i: Int) -> CGPoint {
            let x = values.count == 1
                ? plot.midX
                : plot.minX + plot.width * CGFloat(i) / CGFloat(values.count - 1)
            let yy = plot.maxY - plot.height * CGFloat((values[i] - minV) / range)
            return CGPoint(x: x, y: yy)
        }

        let teal = UIColor(red: 0.18, green: 0.55, blue: 0.52, alpha: 1)

        // Connecting line (only meaningful with 2+ points)
        if values.count > 1 {
            context.setStrokeColor(teal.cgColor)
            context.setLineWidth(1.5)
            let path = CGMutablePath()
            for i in values.indices {
                let p = pointAt(i)
                if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            context.addPath(path)
            context.strokePath()
        }

        // Point markers — visible even for a single day
        context.setFillColor(teal.cgColor)
        for i in values.indices {
            let p = pointAt(i)
            context.fillEllipse(in: CGRect(x: p.x - 2.5, y: p.y - 2.5, width: 5, height: 5))
        }

        // X-axis date labels (first / last)
        let df = DateFormatter(); df.dateFormat = "MMM d"
        (df.string(from: points.first!.0) as NSString)
            .draw(at: CGPoint(x: plot.minX, y: plot.maxY + 2), withAttributes: axisAttrs)
        if points.count > 1 {
            let label = df.string(from: points.last!.0) as NSString
            let size = label.size(withAttributes: axisAttrs)
            label.draw(at: CGPoint(x: plot.maxX - size.width, y: plot.maxY + 2), withAttributes: axisAttrs)
        }
        context.restoreGState()
    }
}
