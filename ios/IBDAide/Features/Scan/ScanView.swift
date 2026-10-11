import SwiftUI
import SwiftData
import PhotosUI

/// Screen 3 — FR-4 barcode safety + FR-5 dish photo safety.
struct ScanView: View {
    @Environment(\.modelContext) private var context
    @Query private var profiles: [UserProfile]
    @Query private var triggers: [TriggerFood]
    @Query private var nutriRules: [NutritionistRule]
    @Query private var cachedProducts: [ScannedProduct]

    enum Mode: String, CaseIterable { case barcode = "Barcode", dish = "Dish photo", lookup = "Lookup" }

    @State private var mode: Mode = .barcode
    @State private var manualBarcode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    @State private var resultTitle: String?
    @State private var resultSubtitle = ""
    @State private var evaluation: FoodEvaluation?
    @State private var uncertain = false   // dish results use "likely contains" language

    @State private var photoItem: PhotosPickerItem?
    @State private var showCamera = false

    private var profile: UserProfile? { profiles.first }
    private var triggerNames: [String] { triggers.map(\.name) }
    private var nutriEntries: [NutritionistEntry] { nutriRules.map(\.engineEntry) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    Picker("Mode", selection: $mode) {
                        ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    switch mode {
                    case .barcode: barcodeSection
                    case .dish: dishSection
                    case .lookup: FoodLookupView().frame(minHeight: 480)
                    }

                    if mode != .lookup {
                        if isLoading { ProgressView().padding() }
                        if let errorMessage {
                            Text(errorMessage).font(.footnote).foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if let evaluation { resultCard(evaluation) }

                        SourcesLink()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Estimates only — can be wrong or incomplete. Not medical advice. Photos never leave your phone.")
                            .font(.caption2).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal)
            }
            .navigationTitle("Scan")
            .toolbar {
                if profile != nil {
                    ToolbarItem(placement: .topBarTrailing) { flareToggle }
                }
            }
        }
    }

    private var flareToggle: some View {
        Button {
            profile?.flareMode.toggle()
            try? context.save()
            if evaluation != nil { reevaluateLast() }
        } label: {
            Label(profile?.flareMode == true ? "Flare mode ON" : "Flare mode off",
                  systemImage: profile?.flareMode == true ? "flame.fill" : "flame")
                .font(.caption)
        }
    }

    // MARK: Barcode

    private var barcodeSection: some View {
        VStack(spacing: 10) {
            if BarcodeScannerView.isSupported {
                BarcodeScannerView { code in
                    Task { await lookup(barcode: code) }
                }
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "camera.on.rectangle").font(.largeTitle).foregroundStyle(.secondary)
                    Text("Camera scanning isn't available on this device. Enter the barcode digits:")
                        .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 120)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            }
            HStack {
                TextField("Barcode number", text: $manualBarcode).keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                Button("Look up") { Task { await lookup(barcode: manualBarcode) } }
                    .buttonStyle(.borderedProminent)
                    .disabled(manualBarcode.filter(\.isNumber).count < 8)
            }
        }
    }

    @State private var lastIngredients: String?
    @State private var lastLabels: [String] = []
    @State private var lastInferred: [String] = []

    private func lookup(barcode: String) async {
        guard !isLoading else { return }
        isLoading = true; errorMessage = nil; evaluation = nil
        defer { isLoading = false }
        do {
            let product: OFFProduct
            if let cached = cachedProducts.first(where: { $0.barcode == barcode.filter(\.isNumber) }) {
                product = OFFProduct(barcode: cached.barcode, name: cached.name,
                                     brand: cached.brand, ingredientsText: cached.ingredientsText)
            } else {
                product = try await OpenFoodFactsClient.fetch(barcode: barcode)
                context.insert(ScannedProduct(barcode: product.barcode, name: product.name,
                                              brand: product.brand, ingredientsText: product.ingredientsText))
                try? context.save()
            }
            guard !product.ingredientsText.isEmpty else {
                errorMessage = "No ingredient list on file for this product. Try photographing the label in Dish photo mode."
                return
            }
            resultTitle = product.name
            resultSubtitle = "\(product.brand.isEmpty ? "" : product.brand + " · ")Open Food Facts · evaluated on-device"
            uncertain = false
            lastIngredients = product.ingredientsText
            evaluation = FoodRulesEngine.evaluate(ingredientsText: product.ingredientsText,
                                                  personalTriggers: triggerNames,
                                                  nutritionist: nutriEntries,
                                                  flareMode: profile?.flareMode ?? false)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Dish photo

    private var dishSection: some View {
        VStack(spacing: 10) {
            if CameraCaptureView.isAvailable {
                Button {
                    showCamera = true
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.fill").font(.largeTitle)
                        Text("Point the camera at the dish\nor its ingredient label")
                            .font(.footnote).multilineTextAlignment(.center)
                        Text("Analyzed on this phone — the photo never leaves your device")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 140)
                    .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityLabel("Take a photo of the dish")
            }

            PhotosPicker(selection: $photoItem, matching: .images) {
                Label(CameraCaptureView.isAvailable ? "Or choose an existing photo"
                                                    : "Choose a photo of the dish or label",
                      systemImage: "photo.on.rectangle")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                Task { await analyzeLibraryItem(item) }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView { image in
                Task { await analyze(image: image) }
            }
            .ignoresSafeArea()
        }
    }

    private func analyzeLibraryItem(_ item: PhotosPickerItem) async {
        defer { photoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            errorMessage = "Couldn't read that photo."
            return
        }
        await analyze(image: image)
    }

    private func analyze(image: UIImage) async {
        isLoading = true; errorMessage = nil; evaluation = nil
        defer { isLoading = false }
        do {
            // Try OCR first — if the photo is an ingredient label, this is exact.
            let ocr = try await IngredientInference.ocrText(from: image)
            if ocr.lowercased().contains("ingredient") || ocr.count > 120 {
                resultTitle = "Ingredient label"
                resultSubtitle = "Read on-device with text recognition"
                uncertain = false
                lastIngredients = ocr
                evaluation = FoodRulesEngine.evaluate(ingredientsText: ocr,
                                                      personalTriggers: triggerNames,
                                                      nutritionist: nutriEntries,
                                                      flareMode: profile?.flareMode ?? false)
                return
            }
            // Otherwise treat as a dish photo.
            let dish = try await IngredientInference.analyzeDish(image: image)
            guard !dish.likelyIngredients.isEmpty || !dish.labels.isEmpty else {
                errorMessage = "Couldn't identify this dish. Try a clearer photo or the ingredient label."
                return
            }
            uncertain = true
            lastLabels = dish.labels
            lastInferred = dish.likelyIngredients
            lastIngredients = nil
            let eval = FoodRulesEngine.evaluateDish(labels: dish.labels,
                                                    inferredIngredients: dish.likelyIngredients,
                                                    personalTriggers: triggerNames,
                                                    nutritionist: nutriEntries,
                                                    flareMode: profile?.flareMode ?? false)
            resultTitle = eval.dishName ?? dish.labels.first?.capitalized ?? "Dish"
            resultSubtitle = (dish.usedAppleIntelligence
                ? "Likely ingredients via Apple Intelligence (on-device)"
                : "Likely ingredients via on-device image analysis")
                + (eval.dishName != nil ? " · matched in the built-in food guide" : "")
            evaluation = eval
        } catch {
            errorMessage = "Analysis failed: \(error.localizedDescription)"
        }
    }

    private func reevaluateLast() {
        let flare = profile?.flareMode ?? false
        if let ingredients = lastIngredients {
            evaluation = FoodRulesEngine.evaluate(ingredientsText: ingredients,
                                                  personalTriggers: triggerNames,
                                                  nutritionist: nutriEntries, flareMode: flare)
        } else if !lastLabels.isEmpty || !lastInferred.isEmpty {
            evaluation = FoodRulesEngine.evaluateDish(labels: lastLabels, inferredIngredients: lastInferred,
                                                      personalTriggers: triggerNames,
                                                      nutritionist: nutriEntries, flareMode: flare)
        }
    }

    // MARK: Result card

    private func resultCard(_ eval: FoodEvaluation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(resultTitle ?? "Result").font(.headline)
                    Text(resultSubtitle).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Text(eval.overall.label)
                    .font(.subheadline.bold())
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(Theme.verdictColor(eval.overall).opacity(0.16), in: Capsule())
                    .foregroundStyle(Theme.verdictTextColor(eval.overall))
            }
            if eval.flareMode {
                Label("Flare mode: stricter rules applied", systemImage: "flame.fill")
                    .font(.caption).foregroundStyle(Theme.amberText)
            }
            if let note = eval.dishNote {
                Text(note).font(.caption).foregroundStyle(.secondary).italic()
            }
            if eval.findings.isEmpty {
                Text(uncertain ? "No flagged ingredients among the likely contents."
                               : "No flagged ingredients found.")
                    .font(.subheadline).foregroundStyle(Theme.greenText)
            } else {
                ForEach(eval.findings) { f in
                    HStack(alignment: .top) {
                        Text(uncertain ? "Likely: \(f.ingredient)" : f.ingredient)
                            .font(.subheadline)
                        Spacer()
                        Text(f.isPersonalTrigger ? "Your trigger" : f.verdict.label)
                            .font(.caption.bold())
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Theme.verdictColor(f.verdict).opacity(0.15), in: Capsule())
                            .foregroundStyle(Theme.verdictTextColor(f.verdict))
                    }
                    Text(f.reason + (f.source == .app ? "" : " — \(f.source.rawValue)"))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if !eval.safeFindings.isEmpty {
                Divider()
                ForEach(eval.safeFindings) { f in
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.greenText).font(.caption)
                        Text("\(f.ingredient) — \(f.reason)").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Button {
                let entry = FoodEntry(name: resultTitle ?? "Scanned item")
                entry.source = mode == .barcode ? "barcode" : "dish-scan"
                context.insert(entry)
                try? context.save()
            } label: {
                Label("Log as meal", systemImage: "plus.circle")
            }
            .font(.subheadline)
        }
        .cardStyle()
    }
}
