import UIKit
import Capacitor
import WebKit

class NativeContainerViewController: UIViewController {

    // MARK: - Properties
    private let headerView = UIView()
    private let titleLabel = UILabel()
    private var webView: WKWebView!
    private let composerVC = ChatComposerViewController()
    private let speechManager = SpeechRecognitionManager()
    private let ttsManager = TextToSpeechManager()

    private var isVoiceMode = false
    private var pendingURL: URL?
    private var pendingReadAccessURL: URL?
    private var composerBottomConstraint: NSLayoutConstraint?
    private var currentLanguage: Language = SettingsViewController.getCurrentLanguage()
    private var pendingRestartListeningTask: DispatchWorkItem?
    private var currentPlayingMessageId: String?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        setupHeader()
        setupWebView()
        setupComposer()
        setupSpeechManager()
        setupTTSManager()
        setupLayout()
        setupKeyboardHandling()

        // Load pending URL if set before viewDidLoad
        if let url = pendingURL {
            if let readURL = pendingReadAccessURL {
                webView.loadFileURL(url, allowingReadAccessTo: readURL)
            } else {
                webView.load(URLRequest(url: url))
            }
            pendingURL = nil
            pendingReadAccessURL = nil
        }
    }

    // MARK: - Setup
    private func setupHeader() {
        // ChatGPT-style dark header
        headerView.backgroundColor = UIColor(white: 0.0, alpha: 1.0)

        titleLabel.text = "ChatGPT"
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center

        headerView.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Add menu button (left)
        let menuButton = UIButton(type: .system)
        menuButton.setImage(UIImage(systemName: "line.3.horizontal"), for: .normal)
        menuButton.tintColor = .white
        menuButton.addTarget(self, action: #selector(menuTapped), for: .touchUpInside)
        headerView.addSubview(menuButton)
        menuButton.translatesAutoresizingMaskIntoConstraints = false

        // Add new chat button (right)
        let newChatButton = UIButton(type: .system)
        newChatButton.setImage(UIImage(systemName: "square.and.pencil"), for: .normal)
        newChatButton.tintColor = .white
        headerView.addSubview(newChatButton)
        newChatButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            menuButton.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            menuButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor, constant: 8),
            menuButton.widthAnchor.constraint(equalToConstant: 24),
            menuButton.heightAnchor.constraint(equalToConstant: 24),

            titleLabel.centerXAnchor.constraint(equalTo: headerView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: headerView.centerYAnchor, constant: 8),

            newChatButton.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            newChatButton.centerYAnchor.constraint(equalTo: headerView.centerYAnchor, constant: 8),
            newChatButton.widthAnchor.constraint(equalToConstant: 24),
            newChatButton.heightAnchor.constraint(equalToConstant: 24)
        ])

        // Add subtle border
        let border = UIView()
        border.backgroundColor = UIColor(white: 0.2, alpha: 0.3)
        headerView.addSubview(border)
        border.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            border.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            border.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            border.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            border.heightAnchor.constraint(equalToConstant: 0.5)
        ])
    }

    private func setupWebView() {
        let webConfig = WKWebViewConfiguration()

        // Use WKWebpagePreferences instead of deprecated javaScriptEnabled
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        webConfig.defaultWebpagePreferences = preferences

        webConfig.allowsInlineMediaPlayback = true
        webConfig.mediaTypesRequiringUserActionForPlayback = []

        // Add message handlers BEFORE creating webview
        webConfig.userContentController.add(self, name: "startListening")
        webConfig.userContentController.add(self, name: "speakText")
        webConfig.userContentController.add(self, name: "replayText")
        webConfig.userContentController.add(self, name: "stopAudio")
        webConfig.userContentController.add(self, name: "switchAudio")

        webView = WKWebView(frame: .zero, configuration: webConfig)
        webView.navigationDelegate = self
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.bounces = true
        webView.scrollView.alwaysBounceVertical = true
        webView.isOpaque = false
        // ChatGPT dark background
        webView.backgroundColor = UIColor(white: 0.0, alpha: 1.0)
    }

    private func setupComposer() {
        composerVC.onSend = { [weak self] message in
            self?.sendMessageToWebView(message)
        }

        composerVC.onVoiceToggle = { [weak self] in
            self?.toggleVoiceMode()
        }

        addChild(composerVC)
        composerVC.didMove(toParent: self)
    }

    private func setupSpeechManager() {
        // Set initial language from saved preference
        speechManager.updateLanguage(currentLanguage.speechCode)

        speechManager.onPartialTranscript = { [weak self] text in
            // Show partial in input box
            self?.composerVC.updateInput(text)
            self?.injectTranscriptToWebView(text: text, isPartial: true)
        }

        speechManager.onFinalTranscript = { [weak self] text in
            // Clear input and send final to UI
            self?.composerVC.clearInput()
            self?.injectTranscriptToWebView(text: text, isPartial: false)
            self?.sendMessageToWebView(text)
        }

        speechManager.onError = { [weak self] error in
            self?.showError(error)
        }
    }

    private func setupTTSManager() {
        // Set initial language from saved preference
        ttsManager.updateLanguage(currentLanguage.ttsCode)

        // Initialize TTS providers with API keys from localStorage
        initializeTTSProviders()

        ttsManager.onSpeechStarted = { [weak self] in
            print("🔊 [TTS] Speech started callback")
            // Cancel any pending restart tasks (fixes race condition when tapping replay quickly)
            self?.pendingRestartListeningTask?.cancel()
            self?.pendingRestartListeningTask = nil
            print("🚫 [TTS] Canceled any pending mic restart")
            // Stop listening while speaking
            self?.speechManager.stop()
            self?.notifyListeningStateChanged(listening: false)
            // Notify web layer
            if let messageId = self?.currentPlayingMessageId {
                self?.notifyWebPlaybackStarted(messageId: messageId)
            }
        }

        ttsManager.onSpeechFinished = { [weak self] in
            print("✅ [TTS] Speech finished callback")
            // Notify web layer
            self?.notifyWebPlaybackStopped()
            self?.currentPlayingMessageId = nil
            // Restart listening if in voice mode
            if let self = self, self.isVoiceMode {
                print("🎤 [TTS] Voice mode active, scheduling mic restart in 0.5s...")
                // Cancel any existing pending task
                self.pendingRestartListeningTask?.cancel()
                // Create new task
                let task = DispatchWorkItem { [weak self] in
                    print("⏰ [TTS] Executing scheduled mic restart")
                    self?.startListening()
                    self?.pendingRestartListeningTask = nil
                }
                self.pendingRestartListeningTask = task
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: task)
            }
        }

        ttsManager.onError = { [weak self] error in
            print("❌ [TTS] Error: \(error)")
            self?.showError(error)
        }
    }

    private func initializeTTSProviders() {
        // Load API keys from .env.local (injected at build time)
        let apiKeys: [String: String] = [
            "elevenlabs": "f69b6f515bbaa1a44b3f00a6e737dd0f93c985880a5f58e2cb167bd623097679",
            "botnoi": "VTY5MDE5ODE0NDMwYTQxYWRmNWI1OGMwNDc4MDIyNzQ0NTYxODk0"
        ]

        print("🔑 [TTS] Loaded API keys from build-time configuration")
        ttsManager.initializeProviders(apiKeys: apiKeys)

        // Re-initialize the saved provider now that we have API keys
        if let savedProvider = UserDefaults.standard.string(forKey: "selectedTTSProvider"),
           let provider = TTSProvider(rawValue: savedProvider) {
            let savedVoiceId = UserDefaults.standard.string(forKey: "selectedTTSVoiceId")
            print("🔊 [TTS] Re-initializing saved provider: \(provider.rawValue) with voice: \(savedVoiceId ?? "default")")
            ttsManager.updateProvider(provider, voiceId: savedVoiceId, apiKeys: apiKeys)
        }
    }

    private func setupLayout() {
        view.addSubview(headerView)
        view.addSubview(webView)
        view.addSubview(composerVC.view)

        headerView.translatesAutoresizingMaskIntoConstraints = false
        webView.translatesAutoresizingMaskIntoConstraints = false
        composerVC.view.translatesAutoresizingMaskIntoConstraints = false

        // Store composer bottom constraint so we can animate it with keyboard
        composerBottomConstraint = composerVC.view.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)

        NSLayoutConstraint.activate([
            // Header (ChatGPT-style compact)
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            headerView.heightAnchor.constraint(equalToConstant: 52),

            // WebView
            webView.topAnchor.constraint(equalTo: headerView.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: composerVC.view.topAnchor),

            // Composer (ChatGPT-style compact)
            composerVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            composerVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            composerBottomConstraint!,
            composerVC.view.heightAnchor.constraint(equalToConstant: 70)
        ])
    }

    private func setupKeyboardHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }

        let keyboardHeight = keyboardFrame.height
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.3

        print("⌨️ Keyboard showing, height: \(keyboardHeight)")

        // Animate composer up above keyboard
        composerBottomConstraint?.constant = -keyboardHeight

        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.3

        print("⌨️ Keyboard hiding")

        // Reset composer to bottom
        composerBottomConstraint?.constant = 0

        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Menu
    @objc private func menuTapped() {
        print("📋 [MENU] Opening settings...")

        // Load API keys from localStorage (injected at build time)
        let apiKeys = loadAPIKeys()

        let settingsVC = SettingsViewController(currentLanguage: currentLanguage, apiKeys: apiKeys)
        settingsVC.delegate = self
        let navController = UINavigationController(rootViewController: settingsVC)
        navController.modalPresentationStyle = .formSheet
        present(navController, animated: true)
    }

    private func loadAPIKeys() -> [String: String] {
        // Load API keys from .env.local (injected at build time)
        let keys = [
            "elevenlabs": "f69b6f515bbaa1a44b3f00a6e737dd0f93c985880a5f58e2cb167bd623097679",
            "botnoi": "VTY5MDE5ODE0NDMwYTQxYWRmNWI1OGMwNDc4MDIyNzQ0NTYxODk0"
        ]
        print("🔑 [KEYS] Loaded from build-time configuration")
        return keys
    }

    // MARK: - Voice Mode
    private func toggleVoiceMode() {
        isVoiceMode.toggle()

        if isVoiceMode {
            enterVoiceMode()
        } else {
            exitVoiceMode()
        }
    }

    private func enterVoiceMode() {
        // Keep composer visible, just change to voice mode UI
        composerVC.setVoiceMode(true)
        view.endEditing(true)

        // Notify web view of voice mode
        notifyVoiceModeChanged(enabled: true)

        // Start listening
        startListening()
    }

    private func exitVoiceMode() {
        // Return to chat mode UI
        composerVC.setVoiceMode(false)
        composerVC.clearInput()

        // Notify web view of voice mode
        notifyVoiceModeChanged(enabled: false)

        speechManager.stop()
        notifyListeningStateChanged(listening: false)
    }

    private func startListening() {
        notifyListeningStateChanged(listening: true)
        speechManager.requestPermissionAndStart()
    }

    private func notifyVoiceModeChanged(enabled: Bool) {
        let js = """
        if (window.onVoiceModeChanged) {
            window.onVoiceModeChanged(\(enabled));
        }
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func notifyListeningStateChanged(listening: Bool) {
        let js = """
        if (window.onListeningStateChanged) {
            window.onListeningStateChanged(\(listening));
        }
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    // MARK: - WebView Communication
    func loadWebApp(url: URL, readAccessURL: URL? = nil) {
        if webView != nil {
            if let readURL = readAccessURL {
                webView.loadFileURL(url, allowingReadAccessTo: readURL)
            } else {
                webView.load(URLRequest(url: url))
            }
        } else {
            // Store URLs to load after viewDidLoad
            pendingURL = url
            pendingReadAccessURL = readAccessURL
        }
    }

    private func sendMessageToWebView(_ text: String) {
        print("📤 [NATIVE] sendMessageToWebView called with text: \(text)")

        let escapedText = text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")

        // Check if bridge is ready, retry if not
        let checkAndSend = """
        (function() {
            console.log('🔧 [NATIVE->WEB] Attempting to send message:', "\(escapedText)");
            console.log('🔧 [NATIVE->WEB] window.nativeBridgeReady =', window.nativeBridgeReady);
            console.log('🔧 [NATIVE->WEB] typeof window.onNativeMessage =', typeof window.onNativeMessage);

            if (window.nativeBridgeReady && window.onNativeMessage) {
                console.log('✅ [NATIVE->WEB] Bridge ready, calling handler');
                window.onNativeMessage("\(escapedText)");
                return { success: true, bridgeReady: window.nativeBridgeReady, hasHandler: true };
            } else {
                console.warn('⚠️ [NATIVE->WEB] Bridge not ready', {
                    bridgeReady: window.nativeBridgeReady,
                    hasCallback: !!window.onNativeMessage
                });
                return { success: false, bridgeReady: window.nativeBridgeReady, hasHandler: !!window.onNativeMessage };
            }
        })();
        """

        print("🔍 [NATIVE] Evaluating JavaScript...")
        webView.evaluateJavaScript(checkAndSend) { result, error in
            if let error = error {
                print("❌ [NATIVE] JavaScript evaluation error: \(error)")
                print("❌ [NATIVE] Error details: \(error.localizedDescription)")
                return
            }

            print("✅ [NATIVE] JavaScript evaluated successfully")
            print("📊 [NATIVE] Result: \(String(describing: result))")

            if let resultDict = result as? [String: Any] {
                let success = resultDict["success"] as? Bool ?? false
                let bridgeReady = resultDict["bridgeReady"] as? Bool ?? false
                let hasHandler = resultDict["hasHandler"] as? Bool ?? false

                print("📊 [NATIVE] Bridge status - success: \(success), bridgeReady: \(bridgeReady), hasHandler: \(hasHandler)")

                if !success {
                    // Bridge not ready, retry after a delay
                    print("⏳ [NATIVE] Bridge not ready, retrying in 0.5s...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.sendMessageToWebView(text)
                    }
                } else {
                    print("🎉 [NATIVE] Message sent successfully!")
                }
            }
        }
    }

    private func injectTranscriptToWebView(text: String, isPartial: Bool) {
        let isFinal = !isPartial
        let escapedText = text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")

        let checkAndSend = """
        (function() {
            console.log('🎤 Native attempting to send transcript:', { text: "\(escapedText)", isFinal: \(isFinal) });
            if (window.nativeBridgeReady && window.onNativeTranscript) {
                console.log('✅ Bridge ready, sending transcript');
                window.onNativeTranscript({
                    text: "\(escapedText)",
                    isFinal: \(isFinal)
                });
                return true;
            } else {
                console.warn('⚠️ Bridge not ready for transcript');
                return false;
            }
        })();
        """

        webView.evaluateJavaScript(checkAndSend) { result, error in
            if let error = error {
                print("❌ Error sending transcript to webview: \(error)")
                return
            }

            if let success = result as? Bool, !success {
                // Bridge not ready, retry after a delay
                print("⏳ Bridge not ready, retrying transcript in 0.5s...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.injectTranscriptToWebView(text: text, isPartial: isPartial)
                }
            }
        }
    }

    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - WebView Bridge
    private func setupWebViewBridge() {
        // Expose native functions to webview
        let js = """
        window.startNativeListening = function() {
            console.log('🎤 [WEB->NATIVE] Request to start listening');
            webkit.messageHandlers.startListening.postMessage({});
        };

        window.speakNativeText = function(text) {
            console.log('🔊 [WEB->NATIVE] Request to speak:', text);
            webkit.messageHandlers.speakText.postMessage({ text: text });
        };

        window.replayAudioText = function(text) {
            console.log('🔊 [WEB->NATIVE] Request to replay:', text);
            webkit.messageHandlers.replayText.postMessage({ text: text });
        };

        window.stopAudio = function() {
            console.log('🛑 [WEB->NATIVE] Request to stop audio');
            webkit.messageHandlers.stopAudio.postMessage({});
        };

        window.switchAudio = function(text) {
            console.log('🔄 [WEB->NATIVE] Request to switch audio:', text);
            webkit.messageHandlers.switchAudio.postMessage({ text: text });
        };
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func notifyWebPlaybackStarted(messageId: String) {
        print("📤 [NATIVE->WEB] Notifying playback started: \(messageId)")
        let js = """
        (function() {
            console.log('🔍 [NATIVE->WEB] Checking playback callback...');
            console.log('🔍 [NATIVE->WEB] typeof window.onAudioPlaybackStarted:', typeof window.onAudioPlaybackStarted);

            if (typeof window.onAudioPlaybackStarted === 'function') {
                console.log('✅ [NATIVE->WEB] Calling onAudioPlaybackStarted with:', '\(messageId)');
                try {
                    window.onAudioPlaybackStarted('\(messageId)');
                    console.log('✅ [NATIVE->WEB] Callback executed successfully');
                    return { success: true, called: true };
                } catch (e) {
                    console.error('❌ [NATIVE->WEB] Callback threw error:', e);
                    return { success: false, error: e.toString(), called: true };
                }
            } else {
                console.warn('⚠️ [NATIVE->WEB] Callback not defined, type:', typeof window.onAudioPlaybackStarted);
                return { success: false, called: false, type: typeof window.onAudioPlaybackStarted };
            }
        })();
        """
        webView.evaluateJavaScript(js) { result, error in
            if let error = error {
                print("❌ [NATIVE->WEB] Failed to evaluate start notification: \(error)")
            } else if let resultDict = result as? [String: Any] {
                print("📊 [NATIVE->WEB] Start notification result: \(resultDict)")
            } else {
                print("✅ [NATIVE->WEB] Start notification sent (result: \(String(describing: result)))")
            }
        }
    }

    private func notifyWebPlaybackStopped() {
        print("📤 [NATIVE->WEB] Notifying playback stopped")
        let js = """
        (function() {
            console.log('🔍 [NATIVE->WEB] Checking stop callback...');
            console.log('🔍 [NATIVE->WEB] typeof window.onAudioPlaybackStopped:', typeof window.onAudioPlaybackStopped);

            if (typeof window.onAudioPlaybackStopped === 'function') {
                console.log('✅ [NATIVE->WEB] Calling onAudioPlaybackStopped');
                try {
                    window.onAudioPlaybackStopped();
                    console.log('✅ [NATIVE->WEB] Stop callback executed successfully');
                    return { success: true, called: true };
                } catch (e) {
                    console.error('❌ [NATIVE->WEB] Stop callback threw error:', e);
                    return { success: false, error: e.toString(), called: true };
                }
            } else {
                console.warn('⚠️ [NATIVE->WEB] Stop callback not defined');
                return { success: false, called: false };
            }
        })();
        """
        webView.evaluateJavaScript(js) { result, error in
            if let error = error {
                print("❌ [NATIVE->WEB] Failed to evaluate stop notification: \(error)")
            } else if let resultDict = result as? [String: Any] {
                print("📊 [NATIVE->WEB] Stop notification result: \(resultDict)")
            } else {
                print("✅ [NATIVE->WEB] Stop notification sent (result: \(String(describing: result)))")
            }
        }
    }
}

// MARK: - WKNavigationDelegate
extension NativeContainerViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("✅ [WEBVIEW] Page loaded, setting up bridge...")
        setupWebViewBridge()
    }
}

// MARK: - SettingsViewControllerDelegate
extension NativeContainerViewController: SettingsViewControllerDelegate {
    func settingsDidChangeLanguage(_ language: Language) {
        print("🌍 [SETTINGS] Language changed to: \(language.displayName)")
        currentLanguage = language

        // Update speech recognition language
        speechManager.updateLanguage(language.speechCode)

        // Update TTS language
        ttsManager.updateLanguage(language.ttsCode)

        // Show toast notification
        showToast("Language changed to \(language.displayName)")
    }

    func settingsDidChangeTTSProvider(_ provider: TTSProvider, voiceId: String?) {
        print("🔊 [SETTINGS] TTS Provider changed to: \(provider.displayName), voiceId: \(voiceId ?? "default")")

        // Load API keys from .env.local (injected at build time) and update provider
        let apiKeys = [
            "elevenlabs": "f69b6f515bbaa1a44b3f00a6e737dd0f93c985880a5f58e2cb167bd623097679",
            "botnoi": "VTY5MDE5ODE0NDMwYTQxYWRmNWI1OGMwNDc4MDIyNzQ0NTYxODk0"
        ]

        ttsManager.updateProvider(provider, voiceId: voiceId, apiKeys: apiKeys)

        // Show toast notification
        DispatchQueue.main.async {
            let voiceText = voiceId != nil ? " (\(voiceId!))" : ""
            self.showToast("TTS changed to \(provider.displayName)\(voiceText)")
        }
    }

    private func showToast(_ message: String) {
        let toast = UILabel()
        toast.text = message
        toast.textColor = .white
        toast.backgroundColor = UIColor(white: 0.2, alpha: 0.9)
        toast.textAlignment = .center
        toast.font = .systemFont(ofSize: 14, weight: .medium)
        toast.layer.cornerRadius = 20
        toast.clipsToBounds = true
        toast.alpha = 0

        view.addSubview(toast)
        toast.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: composerVC.view.topAnchor, constant: -16),
            toast.heightAnchor.constraint(equalToConstant: 40),
            toast.widthAnchor.constraint(greaterThanOrEqualToConstant: 200)
        ])

        UIView.animate(withDuration: 0.3, animations: {
            toast.alpha = 1
        }, completion: { _ in
            UIView.animate(withDuration: 0.3, delay: 2.0, animations: {
                toast.alpha = 0
            }, completion: { _ in
                toast.removeFromSuperview()
            })
        })
    }
}

// MARK: - WKScriptMessageHandler
extension NativeContainerViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "startListening" {
            print("📥 [WEB->NATIVE] Received startListening request")
            startListening()
        } else if message.name == "speakText" {
            print("📥 [WEB->NATIVE] Received speakText request")
            if let body = message.body as? [String: Any],
               let text = body["text"] as? String {
                print("🔊 [WEB->NATIVE] Speaking text: '\(text)'")
                // Generate message ID from text hash for tracking (JS-compatible)
                let messageId = getJavaScriptCompatibleHash(for: text)
                currentPlayingMessageId = messageId
                ttsManager.speak(text)
            } else {
                print("⚠️ [WEB->NATIVE] Invalid speakText message format")
            }
        } else if message.name == "replayText" {
            print("📥 [WEB->NATIVE] Received replayText request")
            if let body = message.body as? [String: Any],
               let text = body["text"] as? String {
                print("🔊 [WEB->NATIVE] Replaying cached audio for text")
                // Generate message ID from text hash for tracking (JS-compatible)
                let messageId = getJavaScriptCompatibleHash(for: text)
                currentPlayingMessageId = messageId
                ttsManager.replayAudio(text)
            } else {
                print("⚠️ [WEB->NATIVE] Invalid replayText message format")
            }
        } else if message.name == "stopAudio" {
            print("📥 [WEB->NATIVE] Received stopAudio request")
            ttsManager.stop()
            currentPlayingMessageId = nil
            notifyWebPlaybackStopped()
        } else if message.name == "switchAudio" {
            print("📥 [WEB->NATIVE] Received switchAudio request")
            if let body = message.body as? [String: Any],
               let text = body["text"] as? String {
                print("🔄 [WEB->NATIVE] Switching to new audio for text")
                // Stop current audio first
                ttsManager.stop()
                // Generate new message ID (JS-compatible)
                let messageId = getJavaScriptCompatibleHash(for: text)
                currentPlayingMessageId = messageId
                // Start new playback
                ttsManager.replayAudio(text)
            } else {
                print("⚠️ [WEB->NATIVE] Invalid switchAudio message format")
            }
        }
    }
}
