import AVFoundation

// MARK: - Helper Functions
// JavaScript-compatible hash function (matches the one in index.html)
func getJavaScriptCompatibleHash(for text: String) -> String {
    var hash: Int32 = 0
    for char in text.unicodeScalars {
        let charValue = Int32(char.value)
        hash = ((hash << 5) &- hash) &+ charValue
    }
    return String(abs(hash))
}

class TextToSpeechManager: NSObject, AVSpeechSynthesizerDelegate {

    // MARK: - Properties
    private let synthesizer = AVSpeechSynthesizer()

    var onSpeechStarted: (() -> Void)?
    var onSpeechFinished: (() -> Void)?
    var onError: ((String) -> Void)?

    private var isSpeaking = false
    private var isPlaying = false  // Track if any audio is currently playing
    private var currentLanguageCode: String = "en-US"

    // Multi-provider support
    private var currentProvider: TTSProvider = .native
    private var currentVoiceId: String?
    private var elevenLabsManager: ElevenLabsTTSManager?
    private var botnoiManager: BotnoiTTSManager?

    // Audio cache
    private var audioCache: [String: URL] = [:] // Maps text hash to cached audio file URL
    private var audioPlayer: AVAudioPlayer?

    // MARK: - Initialization
    override init() {
        super.init()
        synthesizer.delegate = self
        loadSavedSettings()
        loadAudioCache()
    }

    private func loadAudioCache() {
        // Load cached audio file paths from UserDefaults
        if let cacheData = UserDefaults.standard.dictionary(forKey: "audioCache") as? [String: String] {
            audioCache = cacheData.compactMapValues { URL(fileURLWithPath: $0) }
            print("🔊 [TTS] Loaded \(audioCache.count) cached audio files")
        }
    }

    private func saveAudioCache() {
        // Save cache paths to UserDefaults
        let cachePaths = audioCache.mapValues { $0.path }
        UserDefaults.standard.set(cachePaths, forKey: "audioCache")
    }

    private func getCacheKey(text: String, provider: TTSProvider, voiceId: String?) -> String {
        // Create unique key for text + provider + voice combination
        // Use MD5-like hash for consistency
        let voice = voiceId ?? "default"
        let combinedString = "\(provider.rawValue)_\(voice)_\(text)"

        // Simple hash that's consistent across calls
        var hash = 0
        for char in combinedString.utf8 {
            hash = 31 &* hash &+ Int(char)
        }

        let key = "\(provider.rawValue)_\(voice)_\(abs(hash))"
        print("🔑 [TTS] Cache key: \(key) for text: '\(text.prefix(50))...'")
        return key
    }

    private func getCachedAudioURL(for key: String) -> URL? {
        if let url = audioCache[key] {
            print("✅ [TTS] Found cached audio: \(url.lastPathComponent)")
            // Verify file exists
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            } else {
                print("⚠️ [TTS] Cached file no longer exists, removing from cache")
                audioCache.removeValue(forKey: key)
                saveAudioCache()
                return nil
            }
        } else {
            print("❌ [TTS] No cached audio found for key: \(key)")
            print("📋 [TTS] Current cache has \(audioCache.count) entries:")
            for (cachedKey, url) in audioCache.prefix(5) {
                print("   - \(cachedKey) -> \(url.lastPathComponent)")
            }
            return nil
        }
    }

    private func cacheAudioData(_ data: Data, for key: String) -> URL? {
        // Save audio to documents directory
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ [TTS] Failed to get documents directory")
            return nil
        }

        let audioDir = documentsPath.appendingPathComponent("AudioCache", isDirectory: true)

        // Create cache directory if needed
        do {
            try FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)
        } catch {
            print("❌ [TTS] Failed to create cache directory: \(error)")
            return nil
        }

        let fileName = "\(key).mp3"
        let fileURL = audioDir.appendingPathComponent(fileName)

        // Write audio data to file
        do {
            try data.write(to: fileURL)
            audioCache[key] = fileURL
            saveAudioCache()
            print("✅ [TTS] Cached audio to: \(fileURL.lastPathComponent)")
            print("📋 [TTS] Cache now has \(audioCache.count) entries")
            return fileURL
        } catch {
            print("❌ [TTS] Failed to cache audio: \(error)")
            return nil
        }
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

    // MARK: - Playback State Management
    private func notifyPlaybackStarted() {
        isPlaying = true
        print("▶️ [TTS] Playback started, isPlaying = true")
        onSpeechStarted?()
    }

    private func notifyPlaybackFinished() {
        isPlaying = false
        print("⏹️ [TTS] Playback finished, isPlaying = false")
        onSpeechFinished?()
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
                self?.notifyPlaybackStarted()
            }
            elevenLabs.onSpeechFinished = { [weak self] in
                self?.notifyPlaybackFinished()
            }
            elevenLabs.onError = { [weak self] error in
                self?.isPlaying = false  // Reset flag on error
                self?.onError?(error)
            }
        } else if let botnoi = manager as? BotnoiTTSManager {
            botnoi.onSpeechStarted = { [weak self] in
                self?.notifyPlaybackStarted()
            }
            botnoi.onSpeechFinished = { [weak self] in
                self?.notifyPlaybackFinished()
            }
            botnoi.onError = { [weak self] error in
                self?.isPlaying = false  // Reset flag on error
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

        // Prevent overlapping audio - ignore if already playing
        if isPlaying {
            print("⚠️ [TTS] Audio already playing, ignoring speak request")
            return
        }

        // Stop any ongoing speech
        stop()

        // Check cache first (except for native TTS)
        if currentProvider != .native {
            let cacheKey = getCacheKey(text: text, provider: currentProvider, voiceId: currentVoiceId)
            if let cachedURL = getCachedAudioURL(for: cacheKey) {
                print("🔊 [TTS] Playing from cache: \(cachedURL.lastPathComponent)")
                playCachedAudio(from: cachedURL)
                return
            }
        }

        // Generate new audio
        switch currentProvider {
        case .native:
            speakNative(text)
        case .elevenlabs:
            speakElevenLabs(text)
        case .botnoi:
            speakBotnoi(text)
        }
    }

    func replayAudio(_ text: String) {
        // Public method for replaying audio (only plays cached audio, never generates new)
        print("🔊 [TTS] replay requested for text")

        // Prevent overlapping audio - ignore if already playing
        if isPlaying {
            print("⚠️ [TTS] Audio already playing, ignoring replay request")
            return
        }

        // CRITICAL: Stop any ongoing playback first (prevents race condition with multiple audio players)
        stop()

        // Search for cached audio with ANY voice for this text
        // This allows replaying even after changing voices
        let foundCache = findCachedAudioForText(text)

        if let cachedURL = foundCache {
            print("🔊 [TTS] Replaying from cache")
            playCachedAudio(from: cachedURL)
        } else {
            // Don't regenerate - replay is for cached audio only
            print("⚠️ [TTS] No cached audio found for replay, skipping")
            onError?("No cached audio available")
        }
    }

    private func findCachedAudioForText(_ text: String) -> URL? {
        // Search through all cached entries for matching text (any provider/voice)
        let textSnippet = String(text.prefix(50))

        for (key, url) in audioCache {
            // Check if this cache entry is for the requested text
            // The key format is: "Provider_Voice_Hash"
            // We can check if the file exists and matches
            if FileManager.default.fileExists(atPath: url.path) {
                // Try each provider/voice combination
                for provider in TTSProvider.allCases {
                    for voiceId in getPossibleVoiceIds(for: provider) {
                        let testKey = getCacheKey(text: text, provider: provider, voiceId: voiceId)
                        if testKey == key {
                            print("🔊 [TTS] Found cached audio: \(key)")
                            return url
                        }
                    }
                }
            }
        }

        return nil
    }

    private func getPossibleVoiceIds(for provider: TTSProvider) -> [String] {
        // Return common voice IDs to search through cache
        switch provider {
        case .elevenlabs:
            return ["21m00Tcm4TlvDq8ikWAM", "AZnzlk1XvdvUeBnXmlld", "EXAVITQu4vr4xnSDxMaL", "ErXwobaYiN019PkySvjV", "MF3mGyEYCl7XYWbV9V6O", "TxGEqnHWrfWFTfGW9XjX"]
        case .botnoi:
            return ["8", "1", "2", "3", "4"]
        case .native:
            return ["default"]
        }
    }

    private func playCachedAudio(from url: URL) {
        do {
            // Read cached data and write to temp file (fixes format issues)
            let audioData = try Data(contentsOf: url)
            print("🔊 [TTS] Loaded cached audio: \(audioData.count) bytes")

            // Detect file format from header (important for BOTNOI which returns WAV)
            let prefix = audioData.prefix(4)
            let isWav = prefix.starts(with: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
            let isMp3 = prefix.starts(with: [0x49, 0x44, 0x33]) || // "ID3"
                        prefix.starts(with: [0xFF, 0xFB]) ||      // MPEG sync
                        prefix.starts(with: [0xFF, 0xFA])         // MPEG sync

            let fileExtension = isWav ? "wav" : isMp3 ? "mp3" : "mp3"
            print("🔊 [TTS] Detected cached audio format: \(fileExtension.uppercased())")

            let tempDir = FileManager.default.temporaryDirectory
            let tempFile = tempDir.appendingPathComponent(UUID().uuidString + ".\(fileExtension)")
            try audioData.write(to: tempFile)
            print("🔊 [TTS] Wrote to temp file: \(tempFile.lastPathComponent)")

            // Configure audio session (non-fatal if it fails - might already be configured)
            let audioSession = AVAudioSession.sharedInstance()
            do {
                // Use playAndRecord to be compatible with speech recognition
                try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.duckOthers, .defaultToSpeaker])
                try audioSession.setActive(true)
                print("✅ [TTS] Audio session configured")
            } catch {
                // Session might already be active, continue anyway
                print("⚠️ [TTS] Audio session already configured or failed: \(error)")
            }

            // Play from temp file
            audioPlayer = try AVAudioPlayer(contentsOf: tempFile)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()

            print("🔊 [TTS] Audio player ready - duration: \(audioPlayer?.duration ?? 0)s")

            // Stop microphone BEFORE starting playback (must be synchronous!)
            if Thread.isMainThread {
                print("🎙️ [TTS] Stopping mic on main thread (sync)")
                self.notifyPlaybackStarted()
            } else {
                print("🎙️ [TTS] Stopping mic - dispatching to main thread (sync)")
                DispatchQueue.main.sync {
                    self.notifyPlaybackStarted()
                }
            }

            let didPlay = audioPlayer?.play() ?? false
            print("✅ [TTS] Playing cached audio from temp file - started: \(didPlay)")
        } catch {
            print("❌ [TTS] Failed to play cached audio: \(error)")
            DispatchQueue.main.async {
                self.onError?("Failed to play audio")
            }
        }
    }

    private func speakNative(_ text: String) {
        // Configure audio session for playback
        let audioSession = AVAudioSession.sharedInstance()
        do {
            // Use playAndRecord to be compatible with speech recognition
            try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.duckOthers, .defaultToSpeaker])
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

        let voiceId = currentVoiceId ?? "8" // Default BOTNOI speaker
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
        audioPlayer?.stop()  // Stop cached audio player too

        // Reset playing flag when manually stopped
        isPlaying = false

        print("✅ [TTS] Stopped successfully")
    }

    // MARK: - AVSpeechSynthesizerDelegate
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        print("🔊 [TTS] Native speech started")
        DispatchQueue.main.async {
            self.notifyPlaybackStarted()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("✅ [TTS] Native speech finished")
        isSpeaking = false

        DispatchQueue.main.async {
            self.notifyPlaybackFinished()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        print("🛑 [TTS] Native speech canceled")
        isSpeaking = false
        isPlaying = false  // Reset flag on cancel
    }

    // MARK: - Helper
    func initializeProviders(apiKeys: [String: String]) {
        if let elevenLabsKey = apiKeys["elevenlabs"] {
            elevenLabsManager = ElevenLabsTTSManager(apiKey: elevenLabsKey, cacheDelegate: self)
            setupProviderCallbacks(for: elevenLabsManager!)
        }

        if let botnoiKey = apiKeys["botnoi"] {
            botnoiManager = BotnoiTTSManager(apiKey: botnoiKey, cacheDelegate: self)
            setupProviderCallbacks(for: botnoiManager!)
        }
    }
}

// MARK: - AVAudioPlayerDelegate (for cached audio)
extension TextToSpeechManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            print("✅ [TTS] Cached audio finished successfully (duration: \(player.duration)s)")
            DispatchQueue.main.async {
                self.notifyPlaybackFinished()
            }
        } else {
            print("❌ [TTS] Cached audio finished UNsuccessfully - not restarting mic")
            self.isPlaying = false  // Reset flag even on failure
            DispatchQueue.main.async {
                self.onError?("Audio playback failed")
            }
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("❌ [TTS] Audio decode error: \(error?.localizedDescription ?? "unknown")")
        self.isPlaying = false  // Reset flag on error
        DispatchQueue.main.async {
            self.onError?("Audio decode error: \(error?.localizedDescription ?? "unknown")")
        }
    }
}

// MARK: - Audio Cache Delegate
protocol AudioCacheDelegate: AnyObject {
    func cacheAudioData(_ data: Data, for text: String, provider: TTSProvider, voiceId: String?)
}

extension TextToSpeechManager: AudioCacheDelegate {
    func cacheAudioData(_ data: Data, for text: String, provider: TTSProvider, voiceId: String?) {
        print("🔊 [TTS] Caching audio: text='\(text.prefix(50))...', provider=\(provider.rawValue), voice=\(voiceId ?? "default")")
        let cacheKey = getCacheKey(text: text, provider: provider, voiceId: voiceId)
        _ = cacheAudioData(data, for: cacheKey)
    }
}
