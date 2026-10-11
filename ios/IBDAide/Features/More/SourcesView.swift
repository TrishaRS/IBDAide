import SwiftUI

/// Guideline 1.4.1: citations for all medical information in the app,
/// reachable from every place that shows guidance (score cards, scan results,
/// lookup, and the More tab).
struct SourcesView: View {

    struct Citation: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
        let url: String
        let usedFor: String
    }

    static let citations: [Citation] = [
        Citation(
            title: "Crohn's & Colitis Foundation — \"What Should I Eat?\"",
            detail: "Patient dietary guidance: common trigger foods during flares (fried, spicy, high-insoluble-fiber, lactose, caffeine, alcohol, sugar alcohols) and generally well-tolerated foods.",
            url: "https://www.crohnscolitisfoundation.org/patientsandcaregivers/diet-and-nutrition/what-should-i-eat",
            usedFor: "Food scan verdicts, safe-food list, flare-mode rules"),
        Citation(
            title: "IOIBD Dietary Guidance for Patients With IBD (Levine A, et al.)",
            detail: "Clinical Gastroenterology and Hepatology, 2020;18(6):1381–1392. International expert consensus on food additives (carrageenan, emulsifiers, maltodextrin, artificial sweeteners, titanium dioxide), red/processed meat, and trans fats in IBD.",
            url: "https://doi.org/10.1016/j.cgh.2020.01.046",
            usedFor: "Ingredient additive rules in food scans and lookup"),
        Citation(
            title: "Harvey-Bradshaw Index (Harvey RF, Bradshaw JM)",
            detail: "\"A simple index of Crohn's-disease activity.\" The Lancet, 1980;315(8167):514. IBD Aide computes a modified, patient-reported adaptation from your logs.",
            url: "https://doi.org/10.1016/S0140-6736(80)92767-1",
            usedFor: "Daily HBI score (Crohn's disease)"),
        Citation(
            title: "Simple Clinical Colitis Activity Index (Walmsley RS, et al.)",
            detail: "\"A simple clinical colitis activity index.\" Gut, 1998;43(1):29–32. IBD Aide computes a modified, patient-reported adaptation from your logs.",
            url: "https://doi.org/10.1136/gut.43.1.29",
            usedFor: "Daily SCCAI score (ulcerative colitis)"),
        Citation(
            title: "IBD-Control Questionnaire (Bodger K, et al.)",
            detail: "\"Development and validation of a rapid, generic measure of disease control from the patient's perspective.\" Gut, 2014;63(7):1092–1102. The in-app check-in is an adapted, unscored variant for personal trend tracking.",
            url: "https://doi.org/10.1136/gutjnl-2013-305600",
            usedFor: "Quality-of-life check-ins"),
        Citation(
            title: "Bristol Stool Form Scale (Lewis SJ, Heaton KW)",
            detail: "\"Stool form scale as a useful guide to intestinal transit time.\" Scandinavian Journal of Gastroenterology, 1997;32(9):920–924.",
            url: "https://doi.org/10.3109/00365529709011203",
            usedFor: "Bristol quick-tap stool logging"),
        Citation(
            title: "Open Food Facts",
            detail: "Open, collaborative food-products database (non-profit). Provides ingredient lists for barcode and product-name lookups.",
            url: "https://world.openfoodfacts.org",
            usedFor: "Packaged-food ingredient data"),
    ]

    var body: some View {
        List {
            Section {
                Text("Everything IBD Aide tells you about food, symptoms, and scores is derived from the published sources below. Tap any source to read it. IBD Aide provides tracking and information only — not medical advice, diagnosis, or treatment. Individual tolerance varies; always consult your healthcare team.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(Self.citations) { c in
                Section {
                    Link(destination: URL(string: c.url)!) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top) {
                                Text(c.title)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                                    .foregroundStyle(Theme.accent)
                            }
                            Text(c.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Used for: \(c.usedFor)")
                                .font(.caption2.bold())
                                .foregroundStyle(Theme.accent)
                        }
                    }
                }
            }
            Section {
                Text("Colonoscopy prep checklist items are generic reminders — always follow the specific prep instructions from your own clinician.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Medical sources")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Compact tappable citation row for embedding under score cards and scan results.
struct SourcesLink: View {
    @State private var showSources = false

    var body: some View {
        Button {
            showSources = true
        } label: {
            Label("View medical sources & citations", systemImage: "text.book.closed")
                .font(.caption)
                .foregroundStyle(Theme.accent)
        }
        .sheet(isPresented: $showSources) {
            NavigationStack {
                SourcesView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showSources = false }
                        }
                    }
            }
        }
    }
}
