import Foundation

struct NewsItem: Identifiable {
    let id: String
    let title: String
    let url: URL?
    let source: String
    let publishedDate: Date
    let isEnglish: Bool
    var translatedTitle: String?

    var displayTitle: String {
        translatedTitle ?? title
    }

    var dateLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日（E）"
        return formatter.string(from: publishedDate)
    }
}

struct NewsSection {
    let date: String
    let items: [NewsItem]
}
