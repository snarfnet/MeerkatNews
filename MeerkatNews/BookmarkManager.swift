import Foundation

@MainActor
class BookmarkManager: ObservableObject {
    @Published var bookmarks: [NewsItem] = []
    private let key = "savedBookmarks"

    init() {
        load()
    }

    func isBookmarked(_ item: NewsItem) -> Bool {
        bookmarks.contains { $0.id == item.id }
    }

    func toggle(_ item: NewsItem) {
        if let idx = bookmarks.firstIndex(where: { $0.id == item.id }) {
            bookmarks.remove(at: idx)
        } else {
            bookmarks.insert(item, at: 0)
        }
        save()
    }

    private func save() {
        let data = bookmarks.map { BookmarkData(id: $0.id, title: $0.title, urlString: $0.url?.absoluteString ?? "", source: $0.source, publishedDate: $0.publishedDate, isEnglish: $0.isEnglish, translatedTitle: $0.translatedTitle) }
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([BookmarkData].self, from: data) else { return }
        bookmarks = decoded.map { NewsItem(id: $0.id, title: $0.title, url: URL(string: $0.urlString), source: $0.source, publishedDate: $0.publishedDate, isEnglish: $0.isEnglish, translatedTitle: $0.translatedTitle) }
    }
}

private struct BookmarkData: Codable {
    let id: String
    let title: String
    let urlString: String
    let source: String
    let publishedDate: Date
    let isEnglish: Bool
    let translatedTitle: String?
}
