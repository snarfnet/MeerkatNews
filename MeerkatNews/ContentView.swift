import SwiftUI
import SafariServices
import Translation

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

struct ContentView: View {
    @StateObject private var vm = NewsViewModel()
    @AppStorage("fontSize") private var fontSizeRaw: String = FontSizeOption.medium.rawValue
    @State private var translationConfig: TranslationSession.Configuration?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var fontSize: FontSizeOption { FontSizeOption(rawValue: fontSizeRaw) ?? .medium }
    private var headerHeight: CGFloat { horizontalSizeClass == .regular ? 320 : 160 }

    var body: some View {
        VStack(spacing: 0) {
            BannerAdView(adUnitID: kTopBannerID)
                .frame(height: 50)

            NavigationStack {
                Group {
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
                                        NewsRow(item: item, fontSize: fontSize)
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
                .navigationTitle("ミーアキャットニュース")
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
                }
            }

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
}

struct NewsRow: View {
    let item: NewsItem
    let fontSize: FontSizeOption
    @State private var showSafari = false

    var body: some View {
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
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
