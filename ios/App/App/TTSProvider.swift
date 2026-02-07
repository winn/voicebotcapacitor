import Foundation
import AVFoundation

enum TTSProvider: String, CaseIterable {
    case native = "iOS"
    case elevenlabs = "ElevenLabs"
    case botnoi = "BOTNOI Voice"

    var displayName: String {
        return self.rawValue
    }
}

struct TTSVoice {
    let id: String
    let name: String
    let provider: TTSProvider
    let languages: [String]? // Language codes this voice supports (e.g., ["en", "es"])

    init(id: String, name: String, provider: TTSProvider, languages: [String]? = nil) {
        self.id = id
        self.name = name
        self.provider = provider
        self.languages = languages
    }
}

// ElevenLabs Voice Manager
class ElevenLabsTTSManager: NSObject {

    private let apiKey: String
    private var availableVoices: [TTSVoice] = []
    private weak var cacheDelegate: AudioCacheDelegate?
    private var voicesFetched = false

    var onSpeechStarted: (() -> Void)?
    var onSpeechFinished: (() -> Void)?
    var onError: ((String) -> Void)?

    private var audioPlayer: AVAudioPlayer?
    private var currentText: String?
    private var currentVoiceId: String?

    init(apiKey: String, cacheDelegate: AudioCacheDelegate? = nil) {
        self.apiKey = apiKey
        self.cacheDelegate = cacheDelegate
        super.init()
        loadDefaultVoices()
    }

    private func loadDefaultVoices() {
        // Real ElevenLabs voices with multilingual v2 model support
        // Multilingual voices can attempt Thai, but BOTNOI Voice is recommended for best Thai quality

        availableVoices = [
            // Multilingual voices (work with most languages including Thai)
            TTSVoice(id: "21m00Tcm4TlvDq8ikWAM", name: "Rachel (Multilingual)", provider: .elevenlabs, languages: ["en", "es", "fr", "de", "ja", "zh", "ko", "th"]),
            TTSVoice(id: "TxGEqnHWrfWFTfGW9XjX", name: "Josh (Multilingual)", provider: .elevenlabs, languages: ["en", "es", "fr", "de", "ja", "zh", "ko", "th"]),
            TTSVoice(id: "EXAVITQu4vr4xnSDxMaL", name: "Bella (Multilingual)", provider: .elevenlabs, languages: ["en", "es", "fr", "de", "ja", "zh", "ko", "th"]),
            TTSVoice(id: "AZnzlk1XvdvUeBnXmlld", name: "Domi", provider: .elevenlabs, languages: ["en", "es", "fr", "de", "th"]),
            TTSVoice(id: "ErXwobaYiN019PkySvjV", name: "Antoni", provider: .elevenlabs, languages: ["en", "es", "fr", "de", "th"]),
            TTSVoice(id: "MF3mGyEYCl7XYWbV9V6O", name: "Elli", provider: .elevenlabs, languages: ["en", "es", "fr", "de", "th"]),

            // Spanish native voices
            TTSVoice(id: "GBv7mTt0atIp3Br8iCZE", name: "Diego", provider: .elevenlabs, languages: ["es", "en"]),
            TTSVoice(id: "ThT5KcBeYPX3keUQqHPh", name: "Valentina", provider: .elevenlabs, languages: ["es", "en"]),

            // French native voices
            TTSVoice(id: "D38z5RcWu1voky8WS1ja", name: "Antoine", provider: .elevenlabs, languages: ["fr", "en"]),
            TTSVoice(id: "XB0fDUnXU5powFXDhCwa", name: "Charlotte", provider: .elevenlabs, languages: ["fr", "en"]),

            // German native voices
            TTSVoice(id: "N2lVS1w4EtoT3dr4eOWO", name: "Callum", provider: .elevenlabs, languages: ["de", "en"]),
            TTSVoice(id: "pqHfZKP75CvOlQylNhV4", name: "Lily", provider: .elevenlabs, languages: ["de", "en"])
        ]
    }

    func getAvailableVoices(forLanguage languageCode: String? = nil) -> [TTSVoice] {
        guard let languageCode = languageCode else {
            return availableVoices
        }

        // Extract base language code (e.g., "en" from "en-US")
        let baseLanguageCode = String(languageCode.prefix(2))

        // Filter voices that support this language
        let filtered = availableVoices.filter { voice in
            guard let languages = voice.languages else { return true }
            return languages.contains(baseLanguageCode)
        }

        return filtered.isEmpty ? availableVoices : filtered
    }

    func fetchVoicesFromAPI(completion: @escaping ([TTSVoice]) -> Void) {
        guard !apiKey.isEmpty && !apiKey.contains("your-") else {
            print("⚠️ [ElevenLabs] No API key, using default voices")
            completion(availableVoices)
            return
        }

        guard !voicesFetched else {
            completion(availableVoices)
            return
        }

        let url = URL(string: "https://api.elevenlabs.io/v1/voices")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                print("❌ [ElevenLabs] Failed to fetch voices: \(error)")
                completion(self.availableVoices)
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let voicesArray = json["voices"] as? [[String: Any]] else {
                print("❌ [ElevenLabs] Failed to parse voices response")
                completion(self.availableVoices)
                return
            }

            var fetchedVoices: [TTSVoice] = []
            for voiceData in voicesArray {
                guard let voiceId = voiceData["voice_id"] as? String,
                      let name = voiceData["name"] as? String else {
                    continue
                }

                // Extract language support from labels
                var languages: [String] = []
                if let labels = voiceData["labels"] as? [String: String] {
                    // Check accent label for language
                    if let accent = labels["accent"]?.lowercased() {
                        if accent.contains("english") || accent.contains("american") || accent.contains("british") || accent.contains("australian") {
                            languages.append("en")
                        }
                        if accent.contains("spanish") || accent.contains("mexican") {
                            languages.append("es")
                        }
                        if accent.contains("french") {
                            languages.append("fr")
                        }
                        if accent.contains("german") {
                            languages.append("de")
                        }
                    }

                    // Check use_case for multilingual support
                    if let useCase = labels["use case"]?.lowercased() {
                        if useCase.contains("multilingual") {
                            languages = ["en", "es", "fr", "de", "ja", "zh", "ko", "th"]
                        }
                    }
                }

                // If no languages detected, assume it's an English or multilingual voice
                if languages.isEmpty {
                    languages = ["en"]
                }

                let displayName = "\(name) (\(languages.joined(separator: ", ").uppercased()))"
                fetchedVoices.append(TTSVoice(id: voiceId, name: displayName, provider: .elevenlabs, languages: languages))
            }

            if !fetchedVoices.isEmpty {
                self.availableVoices = fetchedVoices
                self.voicesFetched = true
                print("✅ [ElevenLabs] Fetched \(fetchedVoices.count) voices from API")
            }

            completion(self.availableVoices)
        }.resume()
    }

    func speak(text: String, voiceId: String, completion: @escaping (Error?) -> Void) {
        print("🔊 [ElevenLabs] Speaking with voice: \(voiceId)")

        self.currentText = text
        self.currentVoiceId = voiceId

        guard !apiKey.isEmpty && !apiKey.contains("your-") else {
            let error = NSError(domain: "ElevenLabs", code: 401, userInfo: [NSLocalizedDescriptionKey: "ElevenLabs API key not configured"])
            completion(error)
            return
        }

        let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(voiceId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")

        let body: [String: Any] = [
            "text": text,
            "model_id": "eleven_multilingual_v2",
            "voice_settings": [
                "stability": 0.5,
                "similarity_boost": 0.75
            ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        DispatchQueue.main.async {
            self.onSpeechStarted?()
        }

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                print("❌ [ElevenLabs] Request error: \(error)")
                DispatchQueue.main.async {
                    self.onError?(error.localizedDescription)
                    completion(error)
                }
                return
            }

            guard let data = data else {
                let error = NSError(domain: "ElevenLabs", code: 500, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                DispatchQueue.main.async {
                    self.onError?("No audio data received")
                    completion(error)
                }
                return
            }

            // Save to temporary file first (fixes format issues)
            let tempDir = FileManager.default.temporaryDirectory
            let tempFile = tempDir.appendingPathComponent(UUID().uuidString + ".mp3")

            do {
                try data.write(to: tempFile)

                // Cache audio data
                self.cacheDelegate?.cacheAudioData(data, for: text, provider: .elevenlabs, voiceId: voiceId)

                // Play audio from file
                self.audioPlayer = try AVAudioPlayer(contentsOf: tempFile)
                self.audioPlayer?.delegate = self

                // Configure audio session
                let audioSession = AVAudioSession.sharedInstance()
                // Use playAndRecord to be compatible with speech recognition
                try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.duckOthers, .defaultToSpeaker])
                try audioSession.setActive(true)

                self.audioPlayer?.play()
                print("✅ [ElevenLabs] Playing audio from temp file")
                completion(nil)
            } catch {
                print("❌ [ElevenLabs] Audio playback error: \(error)")
                DispatchQueue.main.async {
                    self.onError?(error.localizedDescription)
                    completion(error)
                }
            }
        }.resume()
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
}

extension ElevenLabsTTSManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("✅ [ElevenLabs] Audio finished")
        DispatchQueue.main.async {
            self.onSpeechFinished?()
        }
    }
}

// BOTNOI Voice Manager
class BotnoiTTSManager: NSObject {

    private let apiKey: String
    private var availableVoices: [TTSVoice] = []
    private weak var cacheDelegate: AudioCacheDelegate?
    private var voicesFetched = false

    var onSpeechStarted: (() -> Void)?
    var onSpeechFinished: (() -> Void)?
    var onError: ((String) -> Void)?

    private var audioPlayer: AVAudioPlayer?
    private var currentText: String?
    private var currentVoiceId: String?

    init(apiKey: String, cacheDelegate: AudioCacheDelegate? = nil) {
        self.apiKey = apiKey
        self.cacheDelegate = cacheDelegate
        super.init()
        loadDefaultVoices()
    }

    private func loadDefaultVoices() {
        // Default BOTNOI voices (Thai speakers) - will be replaced by API fetch
        availableVoices = [
            TTSVoice(id: "8", name: "Speaker 8", provider: .botnoi, languages: ["th"]),
            TTSVoice(id: "1", name: "Speaker 1", provider: .botnoi, languages: ["th"]),
            TTSVoice(id: "2", name: "Speaker 2", provider: .botnoi, languages: ["th"]),
            TTSVoice(id: "3", name: "Speaker 3", provider: .botnoi, languages: ["th"]),
            TTSVoice(id: "4", name: "Speaker 4", provider: .botnoi, languages: ["th"])
        ]
    }

    func getAvailableVoices(forLanguage languageCode: String? = nil) -> [TTSVoice] {
        print("🔊 [BOTNOI] getAvailableVoices called with language: \(languageCode ?? "nil")")
        print("🔊 [BOTNOI] Total available voices: \(availableVoices.count)")

        guard let languageCode = languageCode else {
            return availableVoices
        }

        // Extract base language code (e.g., "th" from "th-TH")
        let baseLanguageCode = String(languageCode.prefix(2))
        print("🔊 [BOTNOI] Filtering for language code: \(baseLanguageCode)")

        // Filter by language
        let filtered = availableVoices.filter { voice in
            guard let languages = voice.languages else {
                print("🔊 [BOTNOI] Voice \(voice.id) has no language info")
                return true
            }
            let matches = languages.contains(baseLanguageCode)
            if !matches {
                print("🔊 [BOTNOI] Voice \(voice.id) (\(voice.name)) doesn't match - has: \(languages)")
            }
            return matches
        }

        print("🔊 [BOTNOI] Filtered to \(filtered.count) voices for \(baseLanguageCode)")
        if filtered.isEmpty {
            print("⚠️ [BOTNOI] No voices found for \(baseLanguageCode)!")
        }

        return filtered.isEmpty ? [] : filtered
    }

    func fetchVoicesFromAPI(completion: @escaping ([TTSVoice]) -> Void) {
        print("🔊 [BOTNOI] fetchVoicesFromAPI called")
        print("🔊 [BOTNOI] API key present: \(!apiKey.isEmpty)")
        print("🔊 [BOTNOI] Already fetched: \(voicesFetched)")

        guard !apiKey.isEmpty && !apiKey.contains("your-") else {
            print("⚠️ [BOTNOI] No valid API key, using default voices")
            completion(availableVoices)
            return
        }

        guard !voicesFetched else {
            print("🔊 [BOTNOI] Already fetched, returning cached voices")
            completion(availableVoices)
            return
        }

        let url = URL(string: "https://api-voice.botnoi.ai/openapi/v1/get_speaker_data_v2")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue(apiKey, forHTTPHeaderField: "botnoi-token")

        print("🔊 [BOTNOI] Fetching speakers from API...")
        print("🔊 [BOTNOI] URL: \(url.absoluteString)")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                print("❌ [BOTNOI] Failed to fetch speakers: \(error)")
                completion(self.availableVoices)
                return
            }

            // Log response status
            if let httpResponse = response as? HTTPURLResponse {
                print("🔊 [BOTNOI] Response status code: \(httpResponse.statusCode)")
            }

            guard let data = data else {
                print("❌ [BOTNOI] No data received")
                completion(self.availableVoices)
                return
            }

            print("🔊 [BOTNOI] Received \(data.count) bytes")

            // Log raw response for debugging
            if let rawString = String(data: data, encoding: .utf8) {
                print("🔊 [BOTNOI] Raw response: \(rawString.prefix(500))...")
            }

            // Parse JSON response (can be array directly or wrapped in object)
            do {
                let json = try JSONSerialization.jsonObject(with: data)

                // Try to get speakers array
                let speakersArray: [[String: Any]]?
                if let directArray = json as? [[String: Any]] {
                    // Response is array directly: [{speaker}, {speaker}]
                    speakersArray = directArray
                    print("🔊 [BOTNOI] Response is direct array")
                } else if let wrapper = json as? [String: Any],
                          let dataArray = wrapper["data"] as? [[String: Any]] {
                    // Response is wrapped: {"data": [{speaker}, {speaker}]}
                    speakersArray = dataArray
                    print("🔊 [BOTNOI] Response is wrapped object")
                } else {
                    speakersArray = nil
                    print("❌ [BOTNOI] Unknown response structure")
                }

                if let speakersArray = speakersArray {
                    print("🔊 [BOTNOI] Parsed array with \(speakersArray.count) speakers")

                    var fetchedVoices: [TTSVoice] = []

                    for speakerData in speakersArray {
                        guard let speakerId = speakerData["speaker_id"] as? String else {
                            continue
                        }

                        // Extract speaker info
                        let engName = speakerData["eng_name"] as? String ?? "Speaker \(speakerId)"
                        let thaiName = speakerData["thai_name"] as? String
                        let gender = speakerData["eng_gender"] as? String ?? ""
                        let availableLanguages = speakerData["available_language"] as? [String] ?? ["th"]
                        let ageStyle = speakerData["eng_age_style"] as? String

                        print("🔊 [BOTNOI] Parsing speaker \(speakerId): \(engName) (\(gender))")

                        // Create display name with gender and age
                        var displayName = engName

                        // Add gender and age in parentheses
                        var attributes: [String] = []
                        if !gender.isEmpty {
                            attributes.append(gender)
                        }
                        if let age = ageStyle, !age.isEmpty {
                            attributes.append(age)
                        }
                        if !attributes.isEmpty {
                            displayName += " (\(attributes.joined(separator: ", ")))"
                        }

                        fetchedVoices.append(TTSVoice(
                            id: speakerId,
                            name: displayName,
                            provider: .botnoi,
                            languages: availableLanguages
                        ))
                    }

                    if !fetchedVoices.isEmpty {
                        print("✅ [BOTNOI] Updating availableVoices with \(fetchedVoices.count) speakers")
                        self.availableVoices = fetchedVoices
                        self.voicesFetched = true
                        print("✅ [BOTNOI] Fetched \(fetchedVoices.count) speakers from API")
                        // Log first few voices for debugging
                        for (index, voice) in fetchedVoices.prefix(3).enumerated() {
                            print("🔊 [BOTNOI] Voice \(index): \(voice.name) - languages: \(voice.languages ?? [])")
                        }
                    } else {
                        print("⚠️ [BOTNOI] No voices fetched from API!")
                    }

                    completion(self.availableVoices)
                } else {
                    print("❌ [BOTNOI] Could not extract speakers array from response")
                    completion(self.availableVoices)
                }
            } catch {
                print("❌ [BOTNOI] JSON parsing error: \(error)")
                completion(self.availableVoices)
            }
        }.resume()
    }

    func speak(text: String, voiceId: String, completion: @escaping (Error?) -> Void) {
        print("🔊 [BOTNOI] Speaking with speaker: \(voiceId)")

        self.currentText = text
        self.currentVoiceId = voiceId

        guard !apiKey.isEmpty && !apiKey.contains("your-") else {
            let error = NSError(domain: "BOTNOI", code: 401, userInfo: [NSLocalizedDescriptionKey: "BOTNOI API key not configured"])
            completion(error)
            return
        }

        let url = URL(string: "https://api-voice.botnoi.ai/openapi/v1/generate_audio_v2")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue(apiKey, forHTTPHeaderField: "botnoi-token")

        let body: [String: Any] = [
            "text": text,
            "speaker": voiceId,
            "volume": 1,
            "speed": 1,
            "type_media": "mp3",
            "save_file": "True",
            "language": "th"
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        print("🔊 [BOTNOI] Sending request to \(url)")

        DispatchQueue.main.async {
            self.onSpeechStarted?()
        }

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                print("❌ [BOTNOI] Request error: \(error)")
                DispatchQueue.main.async {
                    self.onError?(error.localizedDescription)
                    completion(error)
                }
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("🔊 [BOTNOI] Response status: \(httpResponse.statusCode)")
                print("🔊 [BOTNOI] Content-Type: \(httpResponse.allHeaderFields["Content-Type"] ?? "unknown")")
            }

            guard let data = data else {
                let error = NSError(domain: "BOTNOI", code: 500, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                DispatchQueue.main.async {
                    self.onError?("No audio data received")
                    completion(error)
                }
                return
            }

            print("🔊 [BOTNOI] Received \(data.count) bytes")

            // Try to parse JSON response to get audio URL or data
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("🔊 [BOTNOI] Response is JSON with keys: \(Array(json.keys).sorted())")

                // Check if response contains audio_url
                if let audioUrlString = json["audio_url"] as? String,
                   let audioUrl = URL(string: audioUrlString) {
                    print("🔊 [BOTNOI] Got audio URL: \(audioUrlString)")
                    self.downloadAndPlayAudio(from: audioUrl, completion: completion)
                    return
                }

                // Check for other possible fields
                if let audioBase64 = json["audio"] as? String {
                    print("🔊 [BOTNOI] Got base64 audio data")
                    if let audioData = Data(base64Encoded: audioBase64) {
                        self.playAudioData(audioData, completion: completion)
                        return
                    }
                }

                print("⚠️ [BOTNOI] JSON response but no audio_url or audio field")
                print("🔊 [BOTNOI] Full response: \(json)")
            } else {
                // Not JSON, try as raw audio data
                print("🔊 [BOTNOI] Response is binary data, attempting direct playback")
                // Check if it looks like audio data (starts with ID3 or audio header)
                let prefix = data.prefix(4)
                let hexPrefix = prefix.map { String(format: "%02X", $0) }.joined()
                print("🔊 [BOTNOI] Data starts with: \(hexPrefix)")
            }

            // Fallback: try to play data directly as audio
            print("🔊 [BOTNOI] Attempting direct audio playback")
            self.playAudioData(data, completion: completion)
        }.resume()
    }

    private func downloadAndPlayAudio(from url: URL, completion: @escaping (Error?) -> Void) {
        print("🔊 [BOTNOI] Downloading audio from: \(url.absoluteString)")

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                print("❌ [BOTNOI] Audio download error: \(error)")
                DispatchQueue.main.async {
                    self.onError?(error.localizedDescription)
                    completion(error)
                }
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                print("🔊 [BOTNOI] Download response status: \(httpResponse.statusCode)")
                print("🔊 [BOTNOI] Download Content-Type: \(httpResponse.allHeaderFields["Content-Type"] ?? "unknown")")
            }

            guard let data = data else {
                let error = NSError(domain: "BOTNOI", code: 500, userInfo: [NSLocalizedDescriptionKey: "No audio data downloaded"])
                DispatchQueue.main.async {
                    self.onError?("No audio data downloaded")
                    completion(error)
                }
                return
            }

            print("🔊 [BOTNOI] Downloaded \(data.count) bytes")

            // Check data format
            let prefix = data.prefix(4)
            let hexPrefix = prefix.map { String(format: "%02X", $0) }.joined()
            print("🔊 [BOTNOI] Downloaded data starts with: \(hexPrefix)")

            // Cache audio data
            if let text = self.currentText, let voiceId = self.currentVoiceId {
                print("🔊 [BOTNOI] Caching downloaded audio")
                self.cacheDelegate?.cacheAudioData(data, for: text, provider: .botnoi, voiceId: voiceId)
            }

            self.playAudioData(data, completion: completion)
        }.resume()
    }

    private func playAudioData(_ data: Data, completion: @escaping (Error?) -> Void) {
        // Detect file format from header
        let prefix = data.prefix(4)
        let isWav = prefix.starts(with: [0x52, 0x49, 0x46, 0x46]) // "RIFF"
        let isMp3 = prefix.starts(with: [0x49, 0x44, 0x33]) || // "ID3"
                    prefix.starts(with: [0xFF, 0xFB]) ||      // MPEG sync
                    prefix.starts(with: [0xFF, 0xFA])         // MPEG sync

        let fileExtension = isWav ? "wav" : isMp3 ? "mp3" : "audio"
        print("🔊 [BOTNOI] Detected format: \(fileExtension.uppercased())")

        // Save to temporary file with correct extension
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(UUID().uuidString + ".\(fileExtension)")

        print("🔊 [BOTNOI] Attempting to play \(data.count) bytes")

        do {
            try data.write(to: tempFile)
            print("🔊 [BOTNOI] Wrote to temp file: \(tempFile.lastPathComponent)")

            // Play audio from file
            self.audioPlayer = try AVAudioPlayer(contentsOf: tempFile)
            self.audioPlayer?.delegate = self
            self.audioPlayer?.prepareToPlay()

            print("🔊 [BOTNOI] Audio player ready - duration: \(self.audioPlayer?.duration ?? 0)s")

            // Configure audio session
            let audioSession = AVAudioSession.sharedInstance()
            // Use playAndRecord to be compatible with speech recognition
            try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true)

            let didPlay = self.audioPlayer?.play() ?? false
            print("✅ [BOTNOI] Playing audio from temp file - started: \(didPlay)")
            completion(nil)
        } catch {
            print("❌ [BOTNOI] Audio playback error: \(error)")
            DispatchQueue.main.async {
                self.onError?(error.localizedDescription)
                completion(error)
            }
        }
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
}

extension BotnoiTTSManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("✅ [BOTNOI] Audio finished")
        DispatchQueue.main.async {
            self.onSpeechFinished?()
        }
    }
}
