import SwiftUI
import SwiftData

/// FR-12: quality-of-life check-in (adapted from IBD-Control-8; informational).
struct QoLCheckinView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \QoLCheckin.date, order: .reverse) private var checkins: [QoLCheckin]

    @State private var answers: [Int] = Array(repeating: 2, count: QoLCheckin.questions.count)
    @State private var saved = false

    private var lastCheckin: QoLCheckin? { checkins.first }

    var body: some View {
        Form {
            Section {
                Text("Thinking about the last two weeks, how much do you agree with each statement? (0 = not at all, 4 = completely)")
                    .font(.caption).foregroundStyle(.secondary)
                SourcesLink()
                if let last = lastCheckin {
                    Text("Last check-in: \(last.date.formatted(date: .abbreviated, time: .omitted)) — \(last.total)/32")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            ForEach(QoLCheckin.questions.indices, id: \.self) { i in
                Section(QoLCheckin.questions[i]) {
                    Picker("Answer", selection: $answers[i]) {
                        ForEach(0...4, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
            }
            Section {
                Button {
                    context.insert(QoLCheckin(answers: answers))
                    try? context.save()
                    saved = true
                } label: {
                    Text("Save check-in").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .navigationTitle("QoL check-in")
        .alert("Saved", isPresented: $saved) {
            Button("Done") { dismiss() }
        } message: {
            Text("Total: \(answers.reduce(0, +))/32. See the trend in the Trends tab; it's included in your doctor report.")
        }
    }
}
