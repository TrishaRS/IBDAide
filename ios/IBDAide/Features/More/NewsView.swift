import SwiftUI
import SwiftData
import SafariServices

/// FR-10: treatment news feed. Fetched on demand — no server, no identifiers sent.
/// Articles open in an in-app Safari view.
struct NewsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \NewsItem.publishedAt, order: .reverse) private var items: [NewsItem]
    @State private var isRefreshing = false
    @State private var safariItem: SafariItem?

    struct SafariItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    var body: some View {
        List {
            Section {
                Text("Curated updates on IBD treatment advancements. Always discuss findings with your care team before acting on them.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if items.isEmpty && !isRefreshing {
                Text("Pull to refresh to load the latest news.").foregroundStyle(.secondary)
            }
            ForEach(items.prefix(50)) { item in
                Button {
                    item.isRead = true
                    try? context.save()
                    if let url = Self.sanitizedURL(item.link) {
                        safariItem = SafariItem(url: url)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.subheadline.weight(item.isRead ? .regular : .semibold))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        HStack {
                            Text(item.source).font(.caption2.bold()).foregroundStyle(Theme.accent)
                            Text(item.publishedAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption2).foregroundStyle(.secondary)
                            if Self.sanitizedURL(item.link) == nil {
                                Text("no link").font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                        if !item.summary.isEmpty {
                            Text(item.summary).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Treatment news")
        .refreshable { await refresh() }
        .task {
            if items.isEmpty { await refresh() }
        }
        .sheet(item: $safariItem) { item in
            SafariView(url: item.url)
                .ignoresSafeArea()
        }
    }

    /// Feeds sometimes deliver links with stray whitespace, missing schemes, or
    /// unescaped characters — normalize before opening.
    static func sanitizedURL(_ raw: String) -> URL? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        if !s.lowercased().hasPrefix("http://") && !s.lowercased().hasPrefix("https://") {
            s = "https://" + s
        }
        if let url = URL(string: s), url.host != nil { return url }
        if let escaped = s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: escaped), url.host != nil { return url }
        return nil
    }

    private func refresh() async {
        isRefreshing = true
        _ = await NewsFeedService.refresh(context: context)
        isRefreshing = false
    }
}

/// In-app browser (SFSafariViewController) — keeps the user inside IBD Aide
/// with Safari's reader, share, and "open in browser" affordances.
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
