import SwiftUI
import SwiftData

/// Food safety lookup: search the built-in knowledge base (CCF + IOIBD sourced,
/// works offline) and optionally packaged products on Open Food Facts.
/// Only the typed search term goes over the network — never health data.
struct FoodLookupView: View {
    @Query private var profiles: [UserProfile]
    @Query private var triggers: [TriggerFood]
    @Query private var nutriRules: [NutritionistRule]

    @State private var query = ""
    @State private var kbResults: [FoodKnowledgeBase.LookupResult] = []
    @State private var offResults: [OFFProduct] = []
    @State private var offEvaluations: [String: FoodEvaluation] = [:]
    @State private var isSearchingOnline = false
    @State private var onlineMessage: String?

    private var profile: UserProfile? { profiles.first }
    private var flareMode: Bool { profile?.flareMode ?? false }
    private var triggerNames: [String] { triggers.map(\.name) }
    private var nutriEntries: [NutritionistEntry] { nutriRules.map(\.engineEntry) }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search a dish, food, or ingredient…", text: $query)
                    .textInputAutocapitalization(.never)
                    .onChange(of: query) { _, q in
                        kbResults = FoodKnowledgeBase.search(q, personalTriggers: triggerNames, flareMode: flareMode)
                        offResults = []; offEvaluations = [:]; onlineMessage = nil
                    }
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                }
            }
            .padding(10)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))

            ScrollView {
                VStack(spacing: 10) {
                    if query.count >= 2 && kbResults.isEmpty && offResults.isEmpty {
                        Text("No match in the built-in guide.").font(.caption).foregroundStyle(.secondary)
                    }

                    ForEach(Array(kbResults.enumerated()), id: \.offset) { _, result in
                        kbResultCard(result)
                    }

                    if query.count >= 3 {
                        Button {
                            Task { await searchOnline() }
                        } label: {
                            Label(isSearchingOnline ? "Searching…" : "Check packaged products (Open Food Facts)",
                                  systemImage: "network")
                                .font(.subheadline)
                                .frame(maxWidth: .infinity, minHeight: 40)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isSearchingOnline)
                    }
                    if let onlineMessage {
                        Text(onlineMessage).font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(offResults, id: \.barcode) { product in
                        offResultCard(product)
                    }

                    sourcesFooter
                }
            }
        }
    }

    // MARK: Knowledge-base result cards

    @ViewBuilder
    private func kbResultCard(_ result: FoodKnowledgeBase.LookupResult) -> some View {
        switch result {
        case .dish(let dish, let eval):
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(dish.name).font(.subheadline.bold())
                    Spacer()
                    verdictChip(eval.overall)
                }
                Text(dish.note).font(.caption).foregroundStyle(.secondary)
                ForEach(eval.findings.prefix(4)) { f in
                    findingRow(f)
                }
            }
            .cardStyle()
        case .ingredient(let rule):
            let verdict = flareMode ? rule.flare : rule.remission
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(rule.name).font(.subheadline.bold())
                    Spacer()
                    verdictChip(verdict)
                }
                Text(rule.reason).font(.caption).foregroundStyle(.secondary)
                Text("Source: \(rule.source.rawValue)").font(.caption2).foregroundStyle(Theme.accent)
            }
            .cardStyle()
        case .safe(let safe):
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(safe.name).font(.subheadline.bold())
                    Spacer()
                    verdictChip(.green)
                }
                Text(safe.note).font(.caption).foregroundStyle(.secondary)
                Text("Source: \(safe.source.rawValue)").font(.caption2).foregroundStyle(Theme.accent)
            }
            .cardStyle()
        }
    }

    private func offResultCard(_ product: OFFProduct) -> some View {
        let eval = offEvaluations[product.barcode]
            ?? FoodRulesEngine.evaluate(ingredientsText: product.ingredientsText,
                                        personalTriggers: triggerNames,
                                        nutritionist: nutriEntries, flareMode: flareMode)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.name).font(.subheadline.bold())
                    Text("\(product.brand.isEmpty ? "" : product.brand + " · ")Open Food Facts")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                verdictChip(eval.overall)
            }
            ForEach(eval.findings.prefix(4)) { f in findingRow(f) }
            if eval.findings.isEmpty {
                Text("No flagged ingredients found.").font(.caption).foregroundStyle(Theme.greenText)
            }
        }
        .cardStyle()
    }

    private func findingRow(_ f: FoodFinding) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 1) {
                Text(f.ingredient).font(.caption.bold())
                Text(f.reason).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            verdictChip(f.verdict, small: true, personal: f.isPersonalTrigger)
        }
    }

    private func verdictChip(_ v: Verdict, small: Bool = false, personal: Bool = false) -> some View {
        Text(personal ? "Your trigger" : v.label)
            .font(small ? .caption2.bold() : .caption.bold())
            .padding(.horizontal, small ? 6 : 10).padding(.vertical, small ? 2 : 4)
            .background(Theme.verdictColor(v).opacity(0.15), in: Capsule())
            .foregroundStyle(Theme.verdictTextColor(v))
    }

    private var sourcesFooter: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Guidance sources").font(.caption.bold())
            Link("Crohn's & Colitis Foundation — What Should I Eat?",
                 destination: URL(string: KBSource.ccf.url)!)
            Link("IOIBD Dietary Guidance for IBD (2020)",
                 destination: URL(string: KBSource.ioibd.url)!)
            Text("Tolerance is individual. Verdicts are informational, not medical advice.")
                .foregroundStyle(.secondary)
        }
        .font(.caption2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
    }

    private func searchOnline() async {
        isSearchingOnline = true; onlineMessage = nil
        defer { isSearchingOnline = false }
        do {
            let products = try await OpenFoodFactsClient.search(name: query)
            offResults = products
            offEvaluations = Dictionary(uniqueKeysWithValues: products.map {
                ($0.barcode, FoodRulesEngine.evaluate(ingredientsText: $0.ingredientsText,
                                                      personalTriggers: triggerNames,
                                                      nutritionist: nutriEntries, flareMode: flareMode))
            })
            if products.isEmpty { onlineMessage = "No packaged products with ingredient lists found for \"\(query)\"." }
        } catch {
            onlineMessage = error.localizedDescription
        }
    }
}
