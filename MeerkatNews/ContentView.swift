import SwiftUI
import SafariServices
import Translation

private let kBottomBannerID = "ca-app-pub-9404799280370656/2546208258"

enum FontSizeOption: String, CaseIterable {
    case small = "小"
    case medium = "中"
    case large = "大"

    var titleSize: CGFloat {
        switch self {
        case .small: return 16
        case .medium: return 18
        case .large: return 21
        }
    }

    var bodySize: CGFloat {
        switch self {
        case .small: return 15
        case .medium: return 17
        case .large: return 20
        }
    }
}

enum Tab: String {
    case news = "ニュース"
    case bookmarks = "保存"
}

struct ContentView: View {
    @StateObject private var vm = NewsViewModel()
    @StateObject private var bookmarkManager = BookmarkManager()
    @StateObject private var speechManager = SpeechManager()
    @AppStorage("fontSize") private var fontSizeRaw: String = FontSizeOption.medium.rawValue
    @State private var translationConfig: TranslationSession.Configuration?
    @State private var selectedTab: Tab = .news

    private var fontSize: FontSizeOption { FontSizeOption(rawValue: fontSizeRaw) ?? .medium }

    var body: some View {
        VStack(spacing: 0) {
            NavigationStack {
                ZStack {
                    MeerkatPalette.background.ignoresSafeArea()

                    Group {
                        if selectedTab == .news {
                            newsListView
                        } else {
                            bookmarkListView
                        }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        Text(selectedTab == .news ? "ミーアキャットニュース" : "保存した記事")
                            .font(.system(size: 17, weight: .bold, design: .serif))
                            .foregroundStyle(MeerkatPalette.ink)
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Picker("文字サイズ", selection: $fontSizeRaw) {
                            ForEach(FontSizeOption.allCases, id: \.rawValue) { size in
                                Text(size.rawValue).tag(size.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 96)
                    }
                }
            }

            MeerkatTabBar(selectedTab: $selectedTab)

            BannerAdView(adUnitID: kBottomBannerID)
                .frame(height: 50)
                .background(MeerkatPalette.ink)
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
            LoadingView()
        } else if vm.sections.isEmpty {
            EmptyStateView(
                title: "記事が見つかりません",
                message: "少し時間をおいて、もう一度読み込んでください。",
                buttonTitle: "再読み込み"
            ) {
                Task { await vm.fetch() }
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 18) {
                    MeerkatHeroView()
                        .padding(.top, 14)

                    ForEach(vm.sections, id: \.date) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(section.date)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(MeerkatPalette.muted)
                                .padding(.horizontal, 22)

                            ForEach(section.items) { item in
                                NewsCard(
                                    item: item,
                                    fontSize: fontSize,
                                    bookmarkManager: bookmarkManager,
                                    speechManager: speechManager
                                )
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                }
                .padding(.bottom, 18)
            }
            .refreshable {
                await vm.fetch()
                translationConfig?.invalidate()
            }
        }
    }

    @ViewBuilder
    private var bookmarkListView: some View {
        if bookmarkManager.bookmarks.isEmpty {
            EmptyStateView(
                title: "保存した記事はまだありません",
                message: "気になるニュースは、カード右上のしおりで保存できます。",
                buttonTitle: nil,
                action: nil
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(bookmarkManager.bookmarks) { item in
                        NewsCard(
                            item: item,
                            fontSize: fontSize,
                            bookmarkManager: bookmarkManager,
                            speechManager: speechManager
                        )
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 18)
            }
        }
    }
}

private enum MeerkatPalette {
    static let background = Color(red: 0.965, green: 0.925, blue: 0.835)
    static let paper = Color(red: 1.0, green: 0.985, blue: 0.945)
    static let ink = Color(red: 0.145, green: 0.105, blue: 0.075)
    static let muted = Color(red: 0.47, green: 0.38, blue: 0.29)
    static let accent = Color(red: 0.74, green: 0.39, blue: 0.16)
    static let sage = Color(red: 0.33, green: 0.48, blue: 0.35)
}

private struct MeerkatHeroView: View {
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image("MeerkatHero")
                .resizable()
                .scaledToFill()
                .frame(height: 230)
                .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.62)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("Meerkat Field Notes")
                    .font(.system(size: 13, weight: .bold, design: .serif))
                    .foregroundStyle(.white.opacity(0.78))

                Text("ミーアキャットだけを、静かに深く。")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text("国内外のニュースを集めて、日本語で読みやすく整えます。")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white.opacity(0.88))
            }
            .padding(22)
        }
        .frame(height: 230)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 24, y: 12)
        .padding(.horizontal, 16)
    }
}

private struct NewsCard: View {
    let item: NewsItem
    let fontSize: FontSizeOption
    @ObservedObject var bookmarkManager: BookmarkManager
    @ObservedObject var speechManager: SpeechManager
    @State private var showDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(item.source)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(MeerkatPalette.accent)
                        .lineLimit(1)

                    if item.isEnglish {
                        Label("翻訳", systemImage: "globe.asia.australia.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(MeerkatPalette.sage)
                    }

                    Spacer()

                    Button {
                        bookmarkManager.toggle(item)
                    } label: {
                        Image(systemName: bookmarkManager.isBookmarked(item) ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(bookmarkManager.isBookmarked(item) ? MeerkatPalette.accent : MeerkatPalette.muted)
                            .frame(width: 36, height: 36)
                            .background(MeerkatPalette.background)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(MeerkatPalette.muted.opacity(0.55))
                }

                Text(item.displayTitle)
                    .font(.system(size: fontSize.titleSize, weight: .bold, design: .serif))
                    .foregroundStyle(MeerkatPalette.ink)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(3)
                    .lineLimit(4)
            }
            .padding(18)
        }
        .background(MeerkatPalette.paper)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.72), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.10), radius: 18, y: 8)
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onTapGesture {
            showDetail = true
        }
        .sheet(isPresented: $showDetail) {
            NewsDetailView(
                item: item,
                fontSize: fontSize,
                bookmarkManager: bookmarkManager,
                speechManager: speechManager
            )
        }
    }
}

private struct NewsDetailView: View {
    let item: NewsItem
    let fontSize: FontSizeOption
    @ObservedObject var bookmarkManager: BookmarkManager
    @ObservedObject var speechManager: SpeechManager
    @Environment(\.dismiss) private var dismiss
    @State private var showSafari = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Image("MeerkatHero")
                        .resizable()
                        .scaledToFill()
                        .frame(height: 210)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                    VStack(alignment: .leading, spacing: 12) {
                        Text(item.source)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(MeerkatPalette.accent)

                        Text(item.displayTitle)
                            .font(.system(size: fontSize.titleSize + 5, weight: .bold, design: .serif))
                            .foregroundStyle(MeerkatPalette.ink)
                            .lineSpacing(5)

                        HStack(spacing: 10) {
                            Button {
                                if let url = item.url {
                                    showSafari = true
                                }
                            } label: {
                                Label("記事を読む", systemImage: "safari")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(MeerkatPrimaryButtonStyle())

                            Button {
                                bookmarkManager.toggle(item)
                            } label: {
                                Image(systemName: bookmarkManager.isBookmarked(item) ? "bookmark.fill" : "bookmark")
                                    .frame(width: 48, height: 48)
                            }
                            .buttonStyle(MeerkatIconButtonStyle())
                        }

                        HStack {
                            Spacer()

                            Button {
                                let text = item.translatedTitle ?? item.title
                                let isEn = item.isEnglish && item.translatedTitle == nil
                                speechManager.speak(text, itemID: item.id, isEnglish: isEn)
                            } label: {
                                Label(
                                    speechManager.currentItemID == item.id ? "停止" : "読み上げ",
                                    systemImage: speechManager.currentItemID == item.id ? "speaker.slash.fill" : "speaker.wave.2.fill"
                                )
                            }
                            .buttonStyle(MeerkatVoiceButtonStyle(isActive: speechManager.currentItemID == item.id))
                        }
                    }
                    .padding(18)
                    .background(MeerkatPalette.paper)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .padding(16)
            }
            .background(MeerkatPalette.background)
            .navigationTitle("記事")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        speechManager.stop()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showSafari) {
                if let url = item.url {
                    SafariView(url: url)
                        .ignoresSafeArea()
                }
            }
        }
    }
}

private struct MeerkatTabBar: View {
    @Binding var selectedTab: Tab

    var body: some View {
        HStack(spacing: 10) {
            TabButton(title: "ニュース", icon: "newspaper.fill", isSelected: selectedTab == .news) {
                selectedTab = .news
            }

            TabButton(title: "保存", icon: "bookmark.fill", isSelected: selectedTab == .bookmarks) {
                selectedTab = .bookmarks
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(MeerkatPalette.paper)
    }
}

private struct TabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 15, weight: .bold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .foregroundStyle(isSelected ? .white : MeerkatPalette.muted)
                .background(isSelected ? MeerkatPalette.ink : MeerkatPalette.background)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image("MeerkatCardWatch")
                .resizable()
                .scaledToFill()
                .frame(width: 132, height: 132)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.14), radius: 16, y: 8)

            ProgressView("ミーアキャットニュースを読み込み中")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(MeerkatPalette.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct EmptyStateView: View {
    let title: String
    let message: String
    let buttonTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: 18) {
            Image("MeerkatCardFamily")
                .resizable()
                .scaledToFill()
                .frame(width: 150, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))

            Text(title)
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundStyle(MeerkatPalette.ink)

            Text(message)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(MeerkatPalette.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 34)

            if let buttonTitle, let action {
                Button(buttonTitle, action: action)
                    .buttonStyle(MeerkatPrimaryButtonStyle())
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct MeerkatPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(MeerkatPalette.ink.opacity(configuration.isPressed ? 0.82 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct MeerkatVoiceButtonStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(isActive ? .white : MeerkatPalette.muted)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(isActive ? Color.red.opacity(0.82) : MeerkatPalette.background)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

private struct MeerkatIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(MeerkatPalette.ink)
            .background(MeerkatPalette.background)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(configuration.isPressed ? 0.78 : 1)
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ vc: SFSafariViewController, context: Context) {}
}
