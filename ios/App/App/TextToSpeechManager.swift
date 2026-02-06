import AVFoundation

class TextToSpeechManager: NSObject, AVSpeechSynthesizerDelegate {

    // MARK: - Properties
    private let synthesizer = AVSpeechSynthesizer()

    var onSpeechStarted: (() -> Void)?
    var onSpeechFinished: (() -> Void)?
    var onError: ((String) -> Void)?

    private var isSpeaking = false
    private var currentLanguageCode: String = "en-US"

    // Multi-provider support
    private var currentProvider: TTSProvider = .native
    private var currentVoiceId: String?
    private var elevenLabsManager: ElevenLabsTTSManager?
    private var botnoiManager: BotnoiTTSManager?

    // MARK: - Initialization
    override init() {
        super.init()
        synthesizer.delegate = self
        loadSavedSettings()
    }

    private func loadSavedSettings() {
        // Load saved TTS provider
        if let savedProvider = UserDefaults.standard.string(forKey: "selectedTTSProvider"),
           let provider = TTSProvider(rawValue: savedProvider) {
            currentProvider = provider
        }

        // Load saved voice ID
        currentVoiceId = UserDefaults.standard.string(forKey: "selectedTTSVoiceId")

        print("🔊 [TTS] Loaded settings - Provider: \(currentProvider.rawValue), VoiceID: \(currentVoiceId ?? "default")")
    }

    // MARK: - Configuration
    func updateLanguage(_ languageCode: String) {
        print("🌍 [TTS] Updating language to: \(languageCode)")
        currentLanguageCode = languageCode
    }

    func updateProvider(_ provider: TTSProvider, voiceId: String?, apiKeys: [String: String]) {
        print("🔊 [TTS] Updating provider to: \(provider.rawValue), voiceID: \(voiceId ?? "default")")
        currentProvider = provider
        currentVoiceId = voiceId

        // Save to UserDefaults
        UserDefaults.standard.set(provider.rawValue, forKey: "selectedTTSProvider")
        if let voiceId = voiceId {
            UserDefaults.standard.set(voiceId, forKey: "selectedTTSVoiceId")
        }

        // Initialize provider managers if needed
        switch provider {
        case .elevenlabs:
            if elevenLabsManager == nil, let apiKey = apiKeys["elevenlabs"] {
                elevenLabsManager = ElevenLabsTTSManager(apiKey: apiKey)
                setupProviderCallbacks(for: elevenLabsManager!)
            }
        case .botnoi:
            if botnoiManager == nil, let apiKey = apiKeys["botnoi"] {
                botnoiManager = BotnoiTTSManager(apiKey: apiKey)
                setupProviderCallbacks(for: botnoiManager!)
            }
        case .native:
            break
        }
    }

    private func setupProviderCallbacks(for manager: Any) {
        if let elevenLabs = manager as? ElevenLabsTTSManager {
            elevenLabs.onSpeechStarted = { [weak self] in
                self?.onSpeechStarted?()
            }
            elevenLabs.onSpeechFinished = { [weak self] in
                self?.onSpeechFinished?()
            }
            elevenLabs.onError = { [weak self] error in
                self?.onError?(error)
            }
        } else if let botnoi = manager as? BotnoiTTSManager {
            botnoi.onSpeechStarted = { [weak self] in
                self?.onSpeechStarted?()
            }
            botnoi.onSpeechFinished = { [weak self] in
                self?.onSpeechFinished?()
            }
            botnoi.onError = { [weak self] error in
                self?.onError?(error)
            }
        }
    }

    // MARK: - Public Methods
    func speak(_ text: String) {
        print("🔊 [TTS] speak called with provider: \(currentProvider.rawValue)")

        guard !text.isEmpty else {
            print("⚠️ [TTS] Empty text, ignoring")
            return
        }

        // Stop any ongoing speech
        stop()

        switch currentProvider {
        case .native:
            speakNative(text)
        case .elevenlabs:
            speakElevenLabs(text)
        case .botnoi:
            speakBotnoi(text)
        }
    }

    private func speakNative(_ text: String) {
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
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0

        if utterance.voice == nil {
            print("⚠️ [TTS] Voice not available for \(currentLanguageCode), using default")
        }

        print("🔊 [TTS] Starting native speech synthesis")
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    private func speakElevenLabs(_ text: String) {
        guard let manager = elevenLabsManager else {
            print("❌ [TTS] ElevenLabs manager not initialized")
            onError?("ElevenLabs not configured")
            return
        }

        let voiceId = currentVoiceId ?? "21m00Tcm4TlvDq8ikWAM" // Rachel as default
        manager.speak(text: text, voiceId: voiceId) { error in
            if let error = error {
                print("❌ [TTS] ElevenLabs error: \(error)")
            }
        }
    }

    private func speakBotnoi(_ text: String) {
        guard let manager = botnoiManager else {
            print("❌ [TTS] BOTNOI manager not initialized")
            onError?("BOTNOI not configured")
            return
        }

        let voiceId = currentVoiceId ?? "th-TH-PremwadeeNeural" // Default Thai voice
        manager.speak(text: text, voiceId: voiceId) { error in
            if let error = error {
                print("❌ [TTS] BOTNOI error: \(error)")
            }
        }
    }

    func stop() {
        print("🛑 [TTS] stop called")

        // Stop all providers
        if isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            isSpeaking = false
        }

        elevenLabsManager?.stop()
        botnoiManager?.stop()

        print("✅ [TTS] Stopped successfully")
    }

    // MARK: - AVSpeechSynthesizerDelegate
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("🔊 [TTS] Native speech started")
        DispatchQueue.main.async {
            self.onSpeechStarted?()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("✅ [TTS] Native speech finished")
        isSpeaking = false

        DispatchQueue.main.async {
            self.onSpeechFinished?()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("🛑 [TTS] Native speech canceled")
        isSpeaking = false
    }

    // MARK: - Helper
    func initializeProviders(apiKeys: [String: String]) {
        if let elevenLabsKey = apiKeys["elevenlabs"] {
            elevenLabsManager = ElevenLabsTTSManager(apiKey: elevenLabsKey)
            setupProviderCallbacks(for: elevenLabsManager!)
        }

        if let botnoiKey = apiKeys["botnoi"] {
            botnoiManager = BotnoiTTSManager(apiKey: botnoiKey)
            setupProviderCallbacks(for: botnoiManager!)
        }
    }
}
