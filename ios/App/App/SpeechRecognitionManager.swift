import Speech
import AVFoundation

class SpeechRecognitionManager: NSObject {

    // MARK: - Properties
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    var onPartialTranscript: ((String) -> Void)?
    var onFinalTranscript: ((String) -> Void)?
    var onError: ((String) -> Void)?

    private var isRecording = false
    private var silenceTimer: Timer?
    private var maxRecordingTimer: Timer?
    private var lastTranscript: String = ""
    private let silenceTimeout: TimeInterval = 1.5 // Stop after 1.5 seconds of silence
    private let maxRecordingTimeout: TimeInterval = 30.0 // Maximum recording time

    // MARK: - Permission & Start
    func requestPermissionAndStart() {
        print("🔐 [SPEECH] Requesting speech recognition permission...")

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                print("🔐 [SPEECH] Permission status: \(status.rawValue)")

                switch status {
                case .authorized:
                    print("✅ [SPEECH] Speech recognition authorized")
                    self?.requestMicrophonePermission()
                case .denied:
                    print("❌ [SPEECH] Speech recognition denied")
                    self?.onError?("Speech recognition permission denied")
                case .restricted:
                    print("❌ [SPEECH] Speech recognition restricted")
                    self?.onError?("Speech recognition restricted on this device")
                case .notDetermined:
                    print("⚠️ [SPEECH] Speech recognition not determined")
                    self?.onError?("Speech recognition not determined")
                @unknown default:
                    print("❌ [SPEECH] Unknown speech recognition status")
                    self?.onError?("Unknown speech recognition status")
                }
            }
        }
    }

    private func requestMicrophonePermission() {
        print("🔐 [SPEECH] Requesting microphone permission...")

        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    print("✅ [SPEECH] Microphone permission granted")
                    self?.startRecording()
                } else {
                    print("❌ [SPEECH] Microphone permission denied")
                    self?.onError?("Microphone permission denied")
                }
            }
        }
    }

    // MARK: - Recording
    func startRecording() {
        print("🎤 [SPEECH] startRecording called, isRecording: \(isRecording)")

        guard !isRecording else {
            print("⚠️ [SPEECH] Already recording, ignoring")
            return
        }

        // Cancel previous task if exists
        recognitionTask?.cancel()
        recognitionTask = nil

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            print("✅ [SPEECH] Audio session configured")
        } catch {
            print("❌ [SPEECH] Audio session error: \(error)")
            onError?("Audio session configuration failed: \(error.localizedDescription)")
            return
        }

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            print("❌ [SPEECH] Failed to create recognition request")
            onError?("Unable to create recognition request")
            return
        }

        recognitionRequest.shouldReportPartialResults = true
        print("✅ [SPEECH] Recognition request created")

        // Get audio input node
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        print("✅ [SPEECH] Audio input node obtained")

        // Remove any existing tap first
        inputNode.removeTap(onBus: 0)

        // Install tap on audio engine
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        print("✅ [SPEECH] Audio tap installed")

        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
            print("✅ [SPEECH] Audio engine started")
        } catch {
            print("❌ [SPEECH] Audio engine start error: \(error)")
            onError?("Audio engine failed to start: \(error.localizedDescription)")
            return
        }

        isRecording = true
        print("✅ [SPEECH] Recording flag set to true")

        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                let transcript = result.bestTranscription.formattedString
                print("🎤 [SPEECH] Transcript received: '\(transcript)', isFinal: \(result.isFinal)")

                // Save last non-empty transcript
                if !transcript.isEmpty {
                    self.lastTranscript = transcript
                }

                if result.isFinal {
                    DispatchQueue.main.async {
                        print("✅ [SPEECH] Calling onFinalTranscript with: '\(self.lastTranscript)'")
                        self.silenceTimer?.invalidate()
                        // Use lastTranscript instead of transcript (which may be empty)
                        if !self.lastTranscript.isEmpty {
                            self.onFinalTranscript?(self.lastTranscript)
                        }
                    }
                    self.stop()
                } else {
                    // Send partial transcript
                    if !transcript.isEmpty {
                        DispatchQueue.main.async {
                            print("📝 [SPEECH] Calling onPartialTranscript")
                            self.onPartialTranscript?(transcript)
                        }

                        // Reset silence timer on each partial result
                        self.resetSilenceTimer()
                    }
                }
            }

            if let error = error {
                print("❌ [SPEECH] Recognition error: \(error)")

                let nsError = error as NSError

                // Error 1110 = "No speech detected" - handle gracefully
                if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 1110 {
                    print("ℹ️ [SPEECH] No speech detected - stopping gracefully")
                    self.stop()
                    return
                }

                // Error 301 = "Recognition request was canceled" - expected when we call stop()
                if nsError.domain == "kLSRErrorDomain" && nsError.code == 301 {
                    print("ℹ️ [SPEECH] Recognition canceled (expected) - already stopped")
                    return
                }

                // Other errors - notify user
                DispatchQueue.main.async {
                    self.onError?("Recognition error: \(error.localizedDescription)")
                }
                self.stop()
            }
        }

        print("✅ [SPEECH] Recognition task started")

        // Don't start silence timer yet - wait for first speech
        // But start maximum recording timer to prevent running forever
        startMaxRecordingTimer()
    }

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceTimeout, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            print("⏰ [SPEECH] Silence timeout - finalizing transcript")

            // Send final transcript and stop
            if !self.lastTranscript.isEmpty {
                DispatchQueue.main.async {
                    self.onFinalTranscript?(self.lastTranscript)
                }
            }
            self.stop()
        }
    }

    private func startMaxRecordingTimer() {
        maxRecordingTimer?.invalidate()
        maxRecordingTimer = Timer.scheduledTimer(withTimeInterval: maxRecordingTimeout, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            print("⏰ [SPEECH] Maximum recording time reached - stopping")

            // If we have a transcript, send it; otherwise just stop
            if !self.lastTranscript.isEmpty {
                DispatchQueue.main.async {
                    self.onFinalTranscript?(self.lastTranscript)
                }
            }
            self.stop()
        }
    }

    func stop() {
        print("🛑 [SPEECH] stop called, isRecording: \(isRecording)")

        guard isRecording else {
            print("⚠️ [SPEECH] Not recording, nothing to stop")
            return
        }

        isRecording = false

        // Invalidate timers
        silenceTimer?.invalidate()
        silenceTimer = nil
        maxRecordingTimer?.invalidate()
        maxRecordingTimer = nil

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionRequest = nil

        recognitionTask?.cancel()
        recognitionTask = nil

        // Clear last transcript
        lastTranscript = ""

        print("✅ [SPEECH] Stopped successfully")
    }
}
