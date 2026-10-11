import SwiftUI
import SwiftData
import UniformTypeIdentifiers

extension NutritionistRule {
    /// Bridge to the rules engine. "ok" → nil verdict (explicitly allowed).
    var engineEntry: NutritionistEntry {
        NutritionistEntry(
            food: foodName,
            verdict: verdictRaw == "avoid" ? .avoid : verdictRaw == "caution" ? .caution : nil,
            note: note)
    }
}

/// FR-16: import and manage the user's own nutritionist/dietitian recommendations.
/// These apply to every food scan and lookup, with priority over the built-in
/// CCF/IOIBD guidance (personal triggers still rank highest).
struct NutritionistPlanView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \NutritionistRule.foodName) private var rules: [NutritionistRule]

    @State private var newFood = ""
    @State private var newVerdict = "caution"
    @State private var newNote = ""
    @State private var showImporter = false
    @State private var importMessage: String?

    private let verdictOptions = [("ok", "Allowed"), ("caution", "Caution"), ("avoid", "Avoid")]

    var body: some View {
        Form {
            Section {
                Text("Add your own dietitian or nutritionist's recommendations. They apply to every food scan and lookup, take priority over the app's general guidance, and — like all your data — never leave this phone.")
                    .font(.footnote).foregroundStyle(.secondary)
            }

            Section("Import a plan file") {
                Button {
                    showImporter = true
                } label: {
                    Label("Import CSV or JSON…", systemImage: "square.and.arrow.down")
                }
                Text("CSV: one line per food — food, verdict, note (verdict: allowed / caution / avoid). JSON: an array of {\"food\", \"verdict\", \"note\"}. Ask your nutritionist's office to export their plan in either format, or type the rows yourself in Notes and save as .txt.")
                    .font(.caption2).foregroundStyle(.secondary)
                if let importMessage {
                    Text(importMessage).font(.caption).foregroundStyle(Theme.accent)
                }
            }

            Section("Add one manually") {
                TextField("Food or ingredient", text: $newFood)
                Picker("Recommendation", selection: $newVerdict) {
                    ForEach(verdictOptions, id: \.0) { value, label in Text(label).tag(value) }
                }
                .pickerStyle(.segmented)
                TextField("Note (optional, e.g. \"small portions only\")", text: $newNote)
                Button("Add") {
                    context.insert(NutritionistRule(
                        foodName: newFood.trimmingCharacters(in: .whitespaces),
                        verdictRaw: newVerdict, note: newNote))
                    try? context.save()
                    newFood = ""; newNote = ""
                }
                .disabled(newFood.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if !rules.isEmpty {
                Section("Your plan (\(rules.count))") {
                    ForEach(rules) { rule in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rule.foodName).font(.subheadline)
                                if !rule.note.isEmpty {
                                    Text(rule.note).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Text(verdictLabel(rule.verdictRaw))
                                .font(.caption.bold())
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(verdictColor(rule.verdictRaw).opacity(0.15), in: Capsule())
                                .foregroundStyle(verdictColor(rule.verdictRaw))
                        }
                    }
                    .onDelete { idx in
                        for i in idx { context.delete(rules[i]) }
                        try? context.save()
                    }
                }
            }

            Section {
                Text("Your nutritionist's plan is followed as entered — IBD Aide does not alter it. If it conflicts with the built-in guidance, the plan wins. Not medical advice; keep your care team informed of what you eat.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Nutritionist plan")
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.commaSeparatedText, .json, .plainText]) { result in
            guard let url = try? result.get() else { return }
            let secured = url.startAccessingSecurityScopedResource()
            defer { if secured { url.stopAccessingSecurityScopedResource() } }
            guard let data = try? Data(contentsOf: url) else {
                importMessage = "Couldn't read that file."
                return
            }
            let imported = Self.parse(data: data)
            guard !imported.isEmpty else {
                importMessage = "No recommendations found in that file. Expected CSV (food, verdict, note) or a JSON array."
                return
            }
            var added = 0
            for item in imported {
                guard !rules.contains(where: { $0.foodName.lowercased() == item.0.lowercased() }) else { continue }
                context.insert(NutritionistRule(foodName: item.0, verdictRaw: item.1, note: item.2))
                added += 1
            }
            try? context.save()
            importMessage = "Imported \(added) recommendation\(added == 1 ? "" : "s")" +
                (imported.count != added ? " (\(imported.count - added) duplicates skipped)." : ".")
        }
    }

    private func verdictLabel(_ raw: String) -> String {
        raw == "ok" ? "Allowed" : raw == "avoid" ? "Avoid" : "Caution"
    }

    private func verdictColor(_ raw: String) -> Color {
        raw == "ok" ? Theme.greenText : raw == "avoid" ? Theme.redText : Theme.amberText
    }

    /// Parses CSV ("food, verdict, note" per line; header row and quotes tolerated)
    /// or a JSON array of {food, verdict, note}.
    static func parse(data: Data) -> [(String, String, String)] {
        // JSON first
        struct Item: Decodable {
            let food: String
            let verdict: String?
            let note: String?
        }
        if let items = try? JSONDecoder().decode([Item].self, from: data) {
            return items.compactMap { item in
                let food = item.food.trimmingCharacters(in: .whitespaces)
                guard !food.isEmpty else { return nil }
                return (food, normalizeVerdict(item.verdict ?? ""), item.note ?? "")
            }
        }
        // CSV / plain text
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        var out: [(String, String, String)] = []
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            let cols = line.components(separatedBy: ",").map {
                $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
            guard let food = cols.first, !food.isEmpty else { continue }
            if food.lowercased() == "food" || food.lowercased() == "item" { continue }  // header row
            let verdict = cols.count > 1 ? normalizeVerdict(cols[1]) : "caution"
            let note = cols.count > 2 ? cols[2...].joined(separator: ", ") : ""
            out.append((food, verdict, note))
        }
        return out
    }

    static func normalizeVerdict(_ s: String) -> String {
        switch s.lowercased().trimmingCharacters(in: .whitespaces) {
        case "ok", "okay", "allowed", "allow", "safe", "yes", "approved", "green": return "ok"
        case "avoid", "no", "never", "eliminate", "red", "exclude": return "avoid"
        default: return "caution"
        }
    }
}
