import SwiftUI
import GoogleMobileAds

struct BannerAdView: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> GADBannerView {
        let banner = GADBannerView(adSize: GADAdSizeBanner)
        banner.adUnitID = adUnitID
        banner.delegate = context.coordinator
        return banner
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {
        guard uiView.rootViewController == nil else { return }
        DispatchQueue.main.async {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let root = scene.keyWindow?.rootViewController else { return }
            uiView.rootViewController = root
            uiView.load(GADRequest())
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, GADBannerViewDelegate {
        func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {}
    }
}
