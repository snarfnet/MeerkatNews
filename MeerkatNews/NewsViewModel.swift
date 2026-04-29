import SwiftUI
import Translation

@MainActor
class NewsViewModel: ObservableObject {
    @Published var sections: [NewsSection] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var needsTranslation = false

    private var allItems: [NewsItem] = []

    private let excludeKeywords = [
        "telescope", "radio telescope", "astronomy", "cosmic", "galaxy",
        "clinical trial", "phase iii", "phase 3", "genentech", "laser",
        "pulsar", "meerkat trial", "sandcat", "vamikibart"
    ]

    private let jaURL = "https://news.google.com/rss/search?q=%E3%83%9F%E3%83%BC%E3%82%A2%E3%82%AD%E3%83%A3%E3%83%83%E3%83%88+%E5%8B%95%E7%89%A9&hl=ja&gl=JP&ceid=JP:ja"
    private let enURL = "https://news.google.com/rss/search?q=meerkat+-telescope+-astronomy+-cosmic+-radio+-clinical&hl=en&gl=US&ceid=US:en"

    func fetch() async {
        isLoading = true
        errorMessage = nil

        async let jaItems = fetchRSS(urlString: jaURL, isEnglish: false)
        async let enItems = fetchRSS(urlString: enURL, isEnglish: true)

        var combined = await jaItems + enItems
        combined.sort { $0.publishedDate > $1.publishedDate }

        var seen = Set<String>()
        combined = combined.filter { seen.insert($0.id).inserted }

        allItems = Array(combined.prefix(100))
        updateSections()
        isLoading = false

        if allItems.contains(where: { $0.isEnglish }) {
            needsTranslation = true
        }
    }

    func translateItems(using session: TranslationSession) async {
        let toTranslate = allItems.filter { $0.isEnglish && $0.translatedTitle == nil }
        guard !toTranslate.isEmpty else { return }

        let requests = toTranslate.map {
            TranslationSession.Request(sourceText: $0.title, clientIdentifier: $0.id)
        }
        do {
            for response in try await session.translations(from: requests) {
                if let idx = allItems.firstIndex(where: { $0.id == response.clientIdentifier }) {
                    allItems[idx].translatedTitle = response.targetText
                }
            }
            updateSections()
        } catch {
            print("Translation error: \(error)")
        }
    }

    private func updateSections() {
        let grouped = Dictionary(grouping: allItems) { $0.dateLabel }
        sections = grouped.keys.sorted { a, b in
            let dateA = grouped[a]!.first!.publishedDate
            let dateB = grouped[b]!.first!.publishedDate
            return dateA > dateB
        }.map { date in
            NewsSection(date: date, items: grouped[date]!.sorted { $0.publishedDate > $1.publishedDate })
        }
    }

    private func fetchRSS(urlString: String, isEnglish: Bool) async -> [NewsItem] {
        guard let url = URL(string: urlString) else { return [] }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let parser = RSSParser(isEnglish: isEnglish, excludeKeywords: excludeKeywords)
            let xmlParser = XMLParser(data: data)
            xmlParser.delegate = parser
            xmlParser.parse()
            return parser.items
        } catch {
            return []
        }
    }
}
