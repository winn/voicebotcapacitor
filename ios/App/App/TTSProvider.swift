import Foundation
import AVFoundation

enum TTSProvider: String, CaseIterable {
    case native = "Default"
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
}

// ElevenLabs Voice Manager
class ElevenLabsTTSManager: NSObject {

    private let apiKey: String
    private var availableVoices: [TTSVoice] = []

    var onSpeechStarted: (() -> Void)?
    var onSpeechFinished: (() -> Void)?
    var onError: ((String) -> Void)?

    private var audioPlayer: AVAudioPlayer?

    init(apiKey: String) {
        self.apiKey = apiKey
        super.init()
        loadDefaultVoices()
    }

    private func loadDefaultVoices() {
        // Default ElevenLabs voices
        availableVoices = [
            TTSVoice(id: "21m00Tcm4TlvDq8ikWAM", name: "Rachel", provider: .elevenlabs),
            TTSVoice(id: "AZnzlk1XvdvUeBnXmlld", name: "Domi", provider: .elevenlabs),
            TTSVoice(id: "EXAVITQu4vr4xnSDxMaL", name: "Bella", provider: .elevenlabs),
            TTSVoice(id: "ErXwobaYiN019PkySvjV", name: "Antoni", provider: .elevenlabs),
            TTSVoice(id: "MF3mGyEYCl7XYWbV9V6O", name: "Elli", provider: .elevenlabs),
            TTSVoice(id: "TxGEqnHWrfWFTfGW9XjX", name: "Josh", provider: .elevenlabs)
        ]
    }

    func getAvailableVoices() -> [TTSVoice] {
        return availableVoices
    }

    func speak(text: String, voiceId: String, completion: @escaping (Error?) -> Void) {
        print("🔊 [ElevenLabs] Speaking with voice: \(voiceId)")

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
            "model_id": "eleven_monolingual_v1",
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

            // Play audio
            do {
                self.audioPlayer = try AVAudioPlayer(data: data)
                self.audioPlayer?.delegate = self

                // Configure audio session
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
                try audioSession.setActive(true)

                self.audioPlayer?.play()
                print("✅ [ElevenLabs] Playing audio")
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

    var onSpeechStarted: (() -> Void)?
    var onSpeechFinished: (() -> Void)?
    var onError: ((String) -> Void)?

    private var audioPlayer: AVAudioPlayer?

    init(apiKey: String) {
        self.apiKey = apiKey
        super.init()
        loadDefaultVoices()
    }

    private func loadDefaultVoices() {
        // Default BOTNOI voices (Thai voices)
        availableVoices = [
            TTSVoice(id: "th-TH-PremwadeeNeural", name: "Premwadee (Female)", provider: .botnoi),
            TTSVoice(id: "th-TH-NiwatNeural", name: "Niwat (Male)", provider: .botnoi),
            TTSVoice(id: "th-TH-AcharaNeural", name: "Achara (Female)", provider: .botnoi)
        ]
    }

    func getAvailableVoices() -> [TTSVoice] {
        return availableVoices
    }

    func speak(text: String, voiceId: String, completion: @escaping (Error?) -> Void) {
        print("🔊 [BOTNOI] Speaking with voice: \(voiceId)")

        guard !apiKey.isEmpty && !apiKey.contains("your-") else {
            let error = NSError(domain: "BOTNOI", code: 401, userInfo: [NSLocalizedDescriptionKey: "BOTNOI API key not configured"])
            completion(error)
            return
        }

        let url = URL(string: "https://api.botnoi.ai/v1/tts")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "text": text,
            "voice": voiceId,
            "language": "th-TH"
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

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

            guard let data = data else {
                let error = NSError(domain: "BOTNOI", code: 500, userInfo: [NSLocalizedDescriptionKey: "No data received"])
                DispatchQueue.main.async {
                    self.onError?("No audio data received")
                    completion(error)
                }
                return
            }

            // Play audio
            do {
                self.audioPlayer = try AVAudioPlayer(data: data)
                self.audioPlayer?.delegate = self

                // Configure audio session
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
                try audioSession.setActive(true)

                self.audioPlayer?.play()
                print("✅ [BOTNOI] Playing audio")
                completion(nil)
            } catch {
                print("❌ [BOTNOI] Audio playback error: \(error)")
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

extension BotnoiTTSManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("✅ [BOTNOI] Audio finished")
        DispatchQueue.main.async {
            self.onSpeechFinished?()
        }
    }
}
