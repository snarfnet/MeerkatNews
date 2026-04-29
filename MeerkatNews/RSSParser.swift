import Foundation

class RSSParser: NSObject, XMLParserDelegate {
    var items: [NewsItem] = []

    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""
    private var currentPubDate = ""
    private var inItem = false
    private let isEnglish: Bool
    private let excludeKeywords: [String]

    private let dateFormatters: [DateFormatter] = {
        let f1 = DateFormatter()
        f1.locale = Locale(identifier: "en_US_POSIX")
        f1.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        let f2 = DateFormatter()
        f2.locale = Locale(identifier: "en_US_POSIX")
        f2.dateFormat = "EEE, d MMM yyyy HH:mm:ss Z"
        return [f1, f2]
    }()

    init(isEnglish: Bool, excludeKeywords: [String]) {
        self.isEnglish = isEnglish
        self.excludeKeywords = excludeKeywords
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        if elementName == "item" {
            inItem = true
            currentTitle = ""
            currentLink = ""
            currentPubDate = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inItem else { return }
        switch currentElement {
        case "title": currentTitle += string
        case "link":  currentLink  += string
        case "pubDate": currentPubDate += string
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        guard elementName == "item", inItem else { return }
        inItem = false

        var title = currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        var source = ""
        if let range = title.range(of: " - ", options: .backwards) {
            source = String(title[range.upperBound...])
            title = String(title[..<range.lowerBound])
        }

        let lowerTitle = title.lowercased()
        if excludeKeywords.contains(where: { lowerTitle.contains($0) }) { return }

        var date = Date()
        let trimmed = currentPubDate.trimmingCharacters(in: .whitespacesAndNewlines)
        for fmt in dateFormatters {
            if let d = fmt.date(from: trimmed) { date = d; break }
        }

        let link = currentLink.trimmingCharacters(in: .whitespacesAndNewlines)
        items.append(NewsItem(
            id: link.isEmpty ? UUID().uuidString : link,
            title: title,
            url: URL(string: link),
            source: source,
            publishedDate: date,
            isEnglish: isEnglish
        ))
    }
}
