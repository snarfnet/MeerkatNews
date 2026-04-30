import SwiftUI
import SafariServices
import Translation
import AVFoundation

private let kTopBannerID    = "ca-app-pub-9404799280370656/6107238800"
private let kBottomBannerID = "ca-app-pub-9404799280370656/2546208258"

enum FontSizeOption: String, CaseIterable {
    case small  = "小"
    case medium = "中"
    case large  = "大"

    var titleSize: CGFloat {
        switch self {
        case .small:  return 12
        case .medium: return 16
        case .large:  return 20
        }
    }
}

enum Tab: String {
    case news = "ニュース"
    case bookmarks = "ブックマーク"
}

struct ContentView: View {
    @StateObject private var vm = NewsViewModel()
    @StateObject private var bookmarkManager = BookmarkManager()
    @StateObject private var speechManager = SpeechManager()
    @AppStorage("fontSize") private var fontSizeRaw: String = FontSizeOption.medium.rawValue
    @State private var translationConfig: TranslationSession.Configuration?
    @State private var selectedTab: Tab = .news
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var fontSize: FontSizeOption { FontSizeOption(rawValue: fontSizeRaw) ?? .medium }
    private var headerHeight: CGFloat { horizontalSizeClass == .regular ? 320 : 160 }

    var body: some View {
        VStack(spacing: 0) {
            BannerAdView(adUnitID: kTopBannerID)
                .frame(height: 50)

            NavigationStack {
                Group {
                    if selectedTab == .news {
                        newsListView
                    } else {
                        bookmarkListView
                    }
                }
                .navigationTitle(selectedTab == .news ? "ミーアキャットニュース" : "ブックマーク")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Picker("文字サイズ", selection: $fontSizeRaw) {
                            ForEach(FontSizeOption.allCases, id: \.rawValue) { size in
                                Text(size.rawValue).tag(size.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 90)
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        if speechManager.isSpeaking {
                            Button { speechManager.stop() } label: {
                                Image(systemName: "speaker.slash.fill")
                                    .foregroundStyle(.red)
                            }
                        }
                    }
                }
            }

            // Tab bar
            HStack {
                TabButton(title: "ニュース", icon: "newspaper.fill", isSelected: selectedTab == .news) {
                    selectedTab = .news
                }
                TabButton(title: "ブックマーク", icon: "bookmark.fill", isSelected: selectedTab == .bookmarks) {
                    selectedTab = .bookmarks
                }
            }
            .padding(.vertical, 8)
            .background(Color(UIColor.systemGroupedBackground))

            BannerAdView(adUnitID: kBottomBannerID)
                .frame(height: 50)
        }
        .task {
            await vm.fetch()
            if vm.needsTranslation {
                translationConfig = TranslationSession.Configuration(
                    source: Locale.Language(identifier: "en"),
                    target: Locale.Language(identifier: "ja")
                )
                vm.needsTranslation = false
            }
        }
        .translationTask(translationConfig) { session in
            await vm.translateItems(using: session)
        }
    }

    @ViewBuilder
    private var newsListView: some View {
        if vm.isLoading && vm.sections.isEmpty {
            ProgressView("読み込み中…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.sections.isEmpty {
            VStack(spacing: 16) {
                Text("記事が見つかりませんでした")
                    .foregroundStyle(.secondary)
                Button("再読み込み") { Task { await vm.fetch() } }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                Section {
                    GeometryReader { geo in
                        Image("MeerkatHeader")
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width)
                            .offset(y: 8)
                    }
                    .frame(height: headerHeight)
                    .clipped()
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                }

                ForEach(vm.sections, id: \.date) { section in
                    Section(header: Text(section.date)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    ) {
                        ForEach(section.items) { item in
                            NewsRow(item: item, fontSize: fontSize, bookmarkManager: bookmarkManager, speechManager: speechManager)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .refreshable {
                await vm.fetch()
                translationConfig?.invalidate()
            }
        }
    }

    @ViewBuilder
    private var bookmarkListView: some View {
        if bookmarkManager.bookmarks.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "bookmark")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("保存した記事はありません")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(bookmarkManager.bookmarks) { item in
                    NewsRow(item: item, fontSize: fontSize, bookmarkManager: bookmarkManager, speechManager: speechManager)
                }
            }
            .listStyle(.plain)
        }
    }
}

struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.caption2)
            }
            .foregroundColor(isSelected ? Color.accentColor : Color.secondary)
            .frame(maxWidth: .infinity)
        }
    }
}

struct NewsRow: View {
    let item: NewsItem
    let fontSize: FontSizeOption
    @ObservedObject var bookmarkManager: BookmarkManager
    @ObservedObject var speechManager: SpeechManager
    @State private var showSafari = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Button {
                showSafari = true
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.displayTitle)
                        .font(.system(size: fontSize.titleSize))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                    HStack {
                        if item.isEnglish && item.translatedTitle == nil {
                            Image(systemName: "globe")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text(item.source)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(spacing: 12) {
                Button {
                    let text = item.translatedTitle ?? item.title
                    let isEn = item.isEnglish && item.translatedTitle == nil
                    speechManager.speak(text, itemID: item.id, isEnglish: isEn)
                } label: {
                    Image(systemName: speechManager.currentItemID == item.id ? "speaker.wave.2.fill" : "speaker.wave.2")
                        .font(.system(size: 14))
                        .foregroundStyle(speechManager.currentItemID == item.id ? .blue : .secondary)
                }
                .buttonStyle(.plain)

                Button {
                    bookmarkManager.toggle(item)
                } label: {
                    Image(systemName: bookmarkManager.isBookmarked(item) ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 14))
                        .foregroundStyle(bookmarkManager.isBookmarked(item) ? .orange : .secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showSafari) {
            if let url = item.url {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
