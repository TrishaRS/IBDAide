import Foundation
import UIKit
import Vision

#if canImport(FoundationModels)
import FoundationModels
#endif

/// On-device food analysis (FR-5). Photos never leave the device.
///
/// Pipeline:
/// 1. `VNClassifyImageRequest` — on-device image classification (all devices, iOS 17+)
/// 2. `VNRecognizeTextRequest` — OCR for photographed ingredient labels
/// 3. Foundation Models (Apple Intelligence, iOS 26+ capable devices) — refines the
///    classification labels into a likely ingredient list. Compiles automatically
///    when built with an SDK that includes FoundationModels; otherwise the
///    heuristic mapping below is used.
enum IngredientInference {

    struct DishResult {
        let labels: [String]          // raw classifier labels, e.g. "pizza"
        let likelyIngredients: [String]
        let usedAppleIntelligence: Bool
    }

    // MARK: OCR (ingredient labels)

    static func ocrText(from image: UIImage) async throws -> String {
        guard let cg = image.cgImage else { return "" }
        return try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            try handler.perform([request])
            let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            return lines.joined(separator: "\n")
        }.value
    }

    // MARK: Dish photo → likely ingredients

    static func analyzeDish(image: UIImage) async throws -> DishResult {
        guard let cg = image.cgImage else { return DishResult(labels: [], likelyIngredients: [], usedAppleIntelligence: false) }

        let labels: [String] = try await Task.detached(priority: .userInitiated) {
            let request = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            try handler.perform([request])
            return (request.results ?? [])
                .filter { $0.confidence > 0.25 }
                .prefix(10)
                .map { $0.identifier.replacingOccurrences(of: "_", with: " ") }
        }.value

        // Try Apple Intelligence refinement when available.
        if let refined = await appleIntelligenceIngredients(for: labels), !refined.isEmpty {
            return DishResult(labels: labels, likelyIngredients: refined, usedAppleIntelligence: true)
        }

        // Heuristic fallback: map common dish labels to typical ingredients.
        var ingredients = Set<String>()
        for label in labels {
            ingredients.insert(label)
            for (dish, parts) in Self.dishMap where label.contains(dish) {
                parts.forEach { ingredients.insert($0) }
            }
        }
        return DishResult(labels: labels, likelyIngredients: Array(ingredients).sorted(), usedAppleIntelligence: false)
    }

    private static func appleIntelligenceIngredients(for labels: [String]) async -> [String]? {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard case .available = SystemLanguageModel.default.availability else { return nil }
            do {
                let session = LanguageModelSession(instructions:
                    "You list likely food ingredients. Reply ONLY with a comma-separated list of ingredients, nothing else.")
                let prompt = "A photo of food was classified as: \(labels.joined(separator: ", ")). List the ingredients this dish most likely contains."
                let response = try await session.respond(to: prompt)
                let items = response.content
                    .components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .filter { !$0.isEmpty && $0.count < 40 }
                return items.isEmpty ? nil : items
            } catch {
                return nil
            }
        }
        #endif
        return nil
    }

    /// Minimal dish → typical-ingredients map used on devices without Apple Intelligence.
    private static let dishMap: [String: [String]] = [
        "pizza": ["wheat flour", "cheese", "tomato", "oil"],
        "burger": ["beef", "wheat bun", "cheese", "fried"],
        "hamburger": ["beef", "wheat bun", "cheese", "fried"],
        "salad": ["raw vegetables", "lettuce", "dressing"],
        "ice cream": ["milk", "cream", "sugar"],
        "french fries": ["potato", "fried", "oil"],
        "fried chicken": ["chicken", "fried", "wheat flour"],
        "curry": ["chili", "spices", "cream"],
        "pasta": ["wheat", "tomato", "cheese"],
        "sushi": ["rice", "fish", "seaweed"],
        "coffee": ["coffee", "caffeine"],
        "beer": ["alcohol", "carbonated"],
        "wine": ["alcohol"],
        "soda": ["carbonated", "high-fructose corn syrup"],
        "popcorn": ["popcorn", "butter"],
        "taco": ["corn", "beef", "cheese", "chili"],
        "smoothie": ["fruit", "milk"],
        "sandwich": ["wheat bread", "cheese"],
        "soup": ["broth", "vegetables"],
        "steak": ["beef"],
        "cake": ["wheat flour", "sugar", "butter"],
        "doughnut": ["wheat flour", "sugar", "fried"],
    ]
}
