import Foundation

/// On-device evaluation of foods/ingredients against the built-in IBD knowledge
/// base (`FoodKnowledgeBase` — sourced from CCF and IOIBD guidance) plus the
/// user's personal trigger list. Informational only — never medical advice.

enum Verdict: Int, Comparable {
    case green = 0, caution = 1, avoid = 2

    static func < (lhs: Verdict, rhs: Verdict) -> Bool { lhs.rawValue < rhs.rawValue }

    var label: String {
        switch self {
        case .green: return "Looks OK"
        case .caution: return "Caution"
        case .avoid: return "Avoid"
        }
    }
}

struct FoodFinding: Identifiable {
    let id = UUID()
    let ingredient: String
    let verdict: Verdict
    let reason: String
    let isPersonalTrigger: Bool
    let source: KBSource
}

struct FoodEvaluation {
    let overall: Verdict
    /// caution/avoid findings, worst first
    let findings: [FoodFinding]
    /// recognized well-tolerated foods (green confirmations)
    let safeFindings: [FoodFinding]
    let flareMode: Bool
    /// dish note when the evaluation came from a recognized dish
    var dishName: String? = nil
    var dishNote: String? = nil
}

/// FR-16: one recommendation from the user's own nutritionist, fed into the engine.
/// `verdict == nil` means "explicitly allowed" — it suppresses general-guidance flags
/// for that food and surfaces as a green confirmation instead.
struct NutritionistEntry {
    let food: String
    let verdict: Verdict?
    let note: String
}

enum FoodRulesEngine {

    /// Evaluate free-text ingredients (comma/newline separated) — used by the
    /// barcode path (Open Food Facts ingredient lists), OCR'd labels, and lookup.
    /// Precedence: personal triggers → nutritionist plan → built-in CCF/IOIBD rules.
    static func evaluate(ingredientsText: String, personalTriggers: [String],
                         nutritionist: [NutritionistEntry] = [], flareMode: Bool) -> FoodEvaluation {
        let normalized = " " + ingredientsText.lowercased() + " "
        let ingredients = ingredientsText.lowercased()
            .components(separatedBy: CharacterSet(charactersIn: ",;\n•("))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ").")))}
            .filter { !$0.isEmpty }

        var findings: [FoodFinding] = []
        var safeFindings: [FoodFinding] = []
        var matchedKeywords = Set<String>()

        // 1. Personal triggers — always "Avoid".
        for trigger in personalTriggers {
            let t = trigger.lowercased().trimmingCharacters(in: .whitespaces)
            guard !t.isEmpty, normalized.contains(t) else { continue }
            let matched = ingredients.first { $0.contains(t) } ?? trigger
            findings.append(FoodFinding(ingredient: matched.capitalized, verdict: .avoid,
                                        reason: "You marked \"\(trigger)\" as a personal trigger",
                                        isPersonalTrigger: true, source: .app))
            matchedKeywords.insert(t)
        }

        // 2. Nutritionist plan (FR-16) — overrides general guidance, not personal triggers.
        for entry in nutritionist {
            let keyword = entry.food.lowercased().trimmingCharacters(in: .whitespaces)
            guard !keyword.isEmpty, normalized.contains(keyword),
                  !matchedKeywords.contains(keyword) else { continue }
            matchedKeywords.insert(keyword)
            let matched = ingredients.first { $0.contains(keyword) } ?? entry.food
            let reason = entry.note.isEmpty
                ? (entry.verdict == nil ? "Approved in your nutritionist's plan"
                                        : "Flagged in your nutritionist's plan")
                : entry.note
            if let verdict = entry.verdict {
                findings.append(FoodFinding(ingredient: matched.capitalized, verdict: verdict,
                                            reason: reason, isPersonalTrigger: false,
                                            source: .nutritionist))
            } else {
                safeFindings.append(FoodFinding(ingredient: matched.capitalized, verdict: .green,
                                                reason: reason, isPersonalTrigger: false,
                                                source: .nutritionist))
            }
        }

        // 3. Knowledge-base flagged rules.
        for rule in FoodKnowledgeBase.rules {
            for keyword in rule.keywords where normalized.contains(keyword) {
                let verdict = flareMode ? rule.flare : rule.remission
                guard verdict != .green else { break }
                guard !matchedKeywords.contains(keyword) else { break }
                matchedKeywords.insert(keyword)
                let matched = ingredients.first { $0.contains(keyword) } ?? rule.name
                findings.append(FoodFinding(ingredient: matched.capitalized, verdict: verdict,
                                            reason: rule.reason, isPersonalTrigger: false, source: rule.source))
                break // one finding per rule
            }
        }

        // 4. Recognized well-tolerated foods (skip any that also hit a flag or trigger).
        for safe in FoodKnowledgeBase.safeFoods {
            for keyword in safe.keywords where normalized.contains(keyword) {
                guard !matchedKeywords.contains(where: { keyword.contains($0) || $0.contains(keyword) }) else { break }
                safeFindings.append(FoodFinding(ingredient: safe.name, verdict: .green,
                                                reason: safe.note, isPersonalTrigger: false, source: safe.source))
                break
            }
        }

        let overall = findings.map(\.verdict).max() ?? .green
        return FoodEvaluation(overall: overall,
                              findings: findings.sorted { $0.verdict > $1.verdict },
                              safeFindings: Array(safeFindings.prefix(6)),
                              flareMode: flareMode)
    }

    /// Evaluate a photographed dish: match the camera's labels against the dish
    /// inventory, merge the dish's typical ingredients with AI-inferred ones,
    /// then evaluate the combined list.
    static func evaluateDish(labels: [String], inferredIngredients: [String],
                             personalTriggers: [String],
                             nutritionist: [NutritionistEntry] = [], flareMode: Bool) -> FoodEvaluation {
        let dish = FoodKnowledgeBase.dish(forLabels: labels)
        var combined = Set(inferredIngredients.map { $0.lowercased() })
        if let dish {
            dish.typicalIngredients.forEach { combined.insert($0.lowercased()) }
        }
        var eval = evaluate(ingredientsText: combined.joined(separator: ", "),
                            personalTriggers: personalTriggers,
                            nutritionist: nutritionist, flareMode: flareMode)
        eval.dishName = dish?.name
        eval.dishNote = dish?.note
        return eval
    }
}
