import AVFoundation

@MainActor
class SpeechManager: ObservableObject {
    @Published var isSpeaking = false
    @Published var currentItemID: String?
    private let synthesizer = AVSpeechSynthesizer()
    private var delegate: SpeechDelegate?

    init() {
        delegate = SpeechDelegate { [weak self] in
            self?.isSpeaking = false
            self?.currentItemID = nil
        }
        synthesizer.delegate = delegate
    }

    func speak(_ text: String, itemID: String, isEnglish: Bool) {
        if isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            if currentItemID == itemID {
                isSpeaking = false
                currentItemID = nil
                return
            }
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: isEnglish ? "en-US" : "ja-JP")
        utterance.rate = 0.5
        currentItemID = itemID
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        currentItemID = nil
    }
}

private class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {
    let onFinish: () -> Void
    init(onFinish: @escaping () -> Void) { self.onFinish = onFinish }
    func speechSynthesizer(_ synth: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in onFinish() }
    }
}
