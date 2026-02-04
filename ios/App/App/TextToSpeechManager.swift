import AVFoundation

class TextToSpeechManager: NSObject, AVSpeechSynthesizerDelegate {

    // MARK: - Properties
    private let synthesizer = AVSpeechSynthesizer()

    var onSpeechStarted: (() -> Void)?
    var onSpeechFinished: (() -> Void)?
    var onError: ((String) -> Void)?

    private var isSpeaking = false
    private var currentLanguageCode: String = "en-US"

    // MARK: - Initialization
    override init() {
        super.init()
        synthesizer.delegate = self
    }

    // MARK: - Public Methods
    func updateLanguage(_ languageCode: String) {
        print("🌍 [TTS] Updating language to: \(languageCode)")
        currentLanguageCode = languageCode
    }

    func speak(_ text: String) {
        print("🔊 [TTS] speak called with text: '\(text)'")

        guard !text.isEmpty else {
            print("⚠️ [TTS] Empty text, ignoring")
            return
        }

        // Stop any ongoing speech
        if isSpeaking {
            print("🛑 [TTS] Stopping previous speech")
            stop()
        }

        // Configure audio session for playback
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("✅ [TTS] Audio session configured for playback")
        } catch {
            print("❌ [TTS] Audio session error: \(error)")
            onError?("Failed to configure audio: \(error.localizedDescription)")
            return
        }

        // Create utterance
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: currentLanguageCode)
        utterance.rate = 0.5 // Normal speed (0.0 = slowest, 1.0 = fastest)
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        if utterance.voice == nil {
            print("⚠️ [TTS] Voice not available for \(currentLanguageCode), using default")
        }

        print("🔊 [TTS] Starting speech synthesis")
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        print("🛑 [TTS] stop called, isSpeaking: \(isSpeaking)")

        guard isSpeaking else {
            print("⚠️ [TTS] Not speaking, nothing to stop")
            return
        }

        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        print("✅ [TTS] Stopped successfully")
    }

    // MARK: - AVSpeechSynthesizerDelegate
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("🔊 [TTS] Speech started")
        DispatchQueue.main.async {
            self.onSpeechStarted?()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("✅ [TTS] Speech finished")
        isSpeaking = false

        DispatchQueue.main.async {
            self.onSpeechFinished?()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("🛑 [TTS] Speech canceled")
        isSpeaking = false
    }
}
