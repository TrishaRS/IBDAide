package com.ibdaide.app.core

import com.ibdaide.app.data.AppDao
import com.ibdaide.app.data.NewsItem
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.xmlpull.v1.XmlPullParser
import org.xmlpull.v1.XmlPullParserFactory
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Locale

/** FR-10: fetch IBD treatment news from curated public feeds. No identifiers sent. */
object NewsFeedService {

    private data class Source(val name: String, val url: String)

    private val sources = listOf(
        Source("FDA", "https://www.fda.gov/about-fda/contact-fda/stay-informed/rss-feeds/press-releases/rss.xml"),
        // Placeholder broad query — replace with a curated feed before Play submission.
        Source("News", "https://news.google.com/rss/search?q=%22inflammatory+bowel+disease%22+treatment+OR+FDA&hl=en-US&gl=US&ceid=US:en"),
    )

    private val keywords = listOf("inflammatory bowel", "crohn", "colitis", "ibd", "biologic", "biosimilar")

    suspend fun refresh(dao: AppDao): Int = withContext(Dispatchers.IO) {
        var newCount = 0
        val existing = dao.news().map { it.guid }.toSet()
        for (source in sources) {
            val items = runCatching { parseRss(fetch(source.url), source.name) }.getOrNull() ?: continue
            val fresh = items.filter { item ->
                val text = (item.title + " " + item.summary).lowercase()
                (source.name != "FDA" || keywords.any { text.contains(it) }) && item.guid !in existing
            }
            dao.insertAllNews(fresh)
            newCount += fresh.size
        }
        newCount
    }

    private fun fetch(url: String): String {
        val conn = URL(url).openConnection() as HttpURLConnection
        conn.connectTimeout = 10_000; conn.readTimeout = 15_000
        conn.setRequestProperty("User-Agent", "IBDAide/1.0 (Android)")
        try { return conn.inputStream.bufferedReader().readText() } finally { conn.disconnect() }
    }

    private val dateFormats = listOf(
        "EEE, dd MMM yyyy HH:mm:ss Z", "EEE, dd MMM yyyy HH:mm:ss zzz", "yyyy-MM-dd'T'HH:mm:ssZ",
    )

    private fun parseDate(s: String): Long {
        for (fmt in dateFormats) {
            runCatching { return SimpleDateFormat(fmt, Locale.US).parse(s)!!.time }
        }
        return System.currentTimeMillis()
    }

    private fun parseRss(xml: String, sourceName: String): List<NewsItem> {
        val parser = XmlPullParserFactory.newInstance().newPullParser()
        parser.setInput(xml.reader())
        val items = mutableListOf<NewsItem>()
        var inItem = false
        var tag = ""
        var title = ""; var link = ""; var guid = ""; var summary = ""; var pub = 0L

        var event = parser.eventType
        while (event != XmlPullParser.END_DOCUMENT) {
            when (event) {
                XmlPullParser.START_TAG -> {
                    tag = parser.name
                    if (tag == "item") { inItem = true; title = ""; link = ""; guid = ""; summary = ""; pub = System.currentTimeMillis() }
                }
                XmlPullParser.TEXT -> if (inItem) {
                    val text = parser.text.trim()
                    if (text.isNotEmpty()) when (tag) {
                        "title" -> title += text
                        "link" -> link += text
                        "guid" -> guid += text
                        "description" -> summary += text.replace(Regex("<[^>]+>"), "").trim()
                        "pubDate" -> pub = parseDate(text)
                    }
                }
                XmlPullParser.END_TAG -> {
                    if (parser.name == "item") {
                        inItem = false
                        if (title.isNotEmpty()) {
                            val id = guid.ifEmpty { link.ifEmpty { title } }
                            items += NewsItem(guid = id, title = title, source = sourceName,
                                link = link, publishedAt = pub, summary = summary.take(400))
                        }
                    }
                    tag = ""
                }
            }
            event = parser.next()
        }
        return items
    }
}
