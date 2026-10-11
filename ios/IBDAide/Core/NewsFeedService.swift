import Foundation
import SwiftData

/// FR-10: fetches IBD treatment news from curated public feeds.
/// Requests carry no user identifiers. Replace/extend `sources` with your
/// curated production feed list before App Store submission.
struct FeedSource {
    let name: String
    let url: URL
}

@MainActor
enum NewsFeedService {

    static let sources: [FeedSource] = [
        // FDA press announcements (filter keywords below narrows to IBD-relevant items)
        FeedSource(name: "FDA", url: URL(string: "https://www.fda.gov/about-fda/contact-fda/stay-informed/rss-feeds/press-releases/rss.xml")!),
        // Broad news query as a placeholder; swap for a curated feed (e.g. CCF) in production.
        FeedSource(name: "News", url: URL(string: "https://news.google.com/rss/search?q=%22inflammatory+bowel+disease%22+treatment+OR+FDA&hl=en-US&gl=US&ceid=US:en")!),
    ]

    private static let keywords = ["inflammatory bowel", "crohn", "colitis", "ibd", "biologic", "biosimilar"]

    /// Fetch all sources, insert new items into the store, return count of new items.
    @discardableResult
    static func refresh(context: ModelContext) async -> Int {
        var newCount = 0
        let existing = (try? context.fetch(FetchDescriptor<NewsItem>())) ?? []
        let existingGuids = Set(existing.map(\.guid))

        for source in sources {
            guard let (data, _) = try? await URLSession.shared.data(from: source.url) else { continue }
            let items = RSSParser.parse(data: data, sourceName: source.name)
            for item in items {
                let text = (item.title + " " + item.summary).lowercased()
                // FDA feed is broad — keep only IBD-relevant items; keep everything from targeted queries
                if source.name == "FDA" && !keywords.contains(where: { text.contains($0) }) { continue }
                guard !existingGuids.contains(item.guid) else { continue }
                context.insert(NewsItem(guid: item.guid, title: item.title, source: source.name,
                                        link: item.link, publishedAt: item.publishedAt, summary: item.summary))
                newCount += 1
            }
        }
        try? context.save()
        return newCount
    }
}

// MARK: - Minimal RSS parser

struct RSSRawItem {
    var guid = ""
    var title = ""
    var link = ""
    var summary = ""
    var publishedAt = Date()
}

final class RSSParser: NSObject, XMLParserDelegate {

    private var items: [RSSRawItem] = []
    private var current: RSSRawItem?
    private var currentElement = ""
    private var buffer = ""
    private let sourceName: String

    private static let dateFormats = [
        "EEE, dd MMM yyyy HH:mm:ss Z",
        "EEE, dd MMM yyyy HH:mm:ss zzz",
        "yyyy-MM-dd'T'HH:mm:ssZ",
    ]

    init(sourceName: String) { self.sourceName = sourceName }

    static func parse(data: Data, sourceName: String) -> [RSSRawItem] {
        let delegate = RSSParser(sourceName: sourceName)
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.items
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String] = [:]) {
        currentElement = elementName
        buffer = ""
        if elementName == "item" { current = RSSRawItem() }
        // Atom-style links carry the URL in an href attribute rather than text content.
        if elementName == "link", let href = attributes["href"], !href.isEmpty {
            buffer = href
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer += string
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        buffer += String(data: CDATABlock, encoding: .utf8) ?? ""
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        guard var item = current else { return }
        let value = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        switch elementName {
        case "title": item.title = value
        case "link": item.link = value
        case "guid": item.guid = value
        case "description":
            item.summary = value
                .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        case "pubDate":
            for fmt in Self.dateFormats {
                let df = DateFormatter()
                df.locale = Locale(identifier: "en_US_POSIX")
                df.dateFormat = fmt
                if let d = df.date(from: value) { item.publishedAt = d; break }
            }
        case "item":
            if item.guid.isEmpty { item.guid = item.link.isEmpty ? item.title : item.link }
            if !item.title.isEmpty { items.append(item) }
            current = nil
            return
        default: break
        }
        current = item
    }
}
