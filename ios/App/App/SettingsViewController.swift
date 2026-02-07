import UIKit
import AVFoundation

protocol SettingsViewControllerDelegate: AnyObject {
    func settingsDidChangeLanguage(_ language: Language)
    func settingsDidChangeTTSProvider(_ provider: TTSProvider, voiceId: String?)
}

struct Language {
    let code: String
    let displayName: String
    let speechCode: String
    let ttsCode: String
}

enum SettingsSection: Int, CaseIterable {
    case language = 0
    case ttsProvider = 1

    var title: String {
        switch self {
        case .language: return "Language"
        case .ttsProvider: return "TTS Provider"
        }
    }
}

class SettingsViewController: UIViewController {

    weak var delegate: SettingsViewControllerDelegate?

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var selectedLanguage: Language
    private var selectedTTSProvider: TTSProvider
    private var selectedVoiceId: String?

    private var expandedSections: Set<Int> = []
    private var apiKeys: [String: String] = [:]

    // Cached TTS managers (keep alive for API callbacks)
    private var elevenLabsManager: ElevenLabsTTSManager?
    private var botnoiManager: BotnoiTTSManager?

    // Supported languages
    static let languages: [Language] = [
        Language(code: "en", displayName: "English", speechCode: "en-US", ttsCode: "en-US"),
        Language(code: "th", displayName: "ไทย (Thai)", speechCode: "th-TH", ttsCode: "th-TH"),
        Language(code: "es", displayName: "Español", speechCode: "es-ES", ttsCode: "es-ES"),
        Language(code: "fr", displayName: "Français", speechCode: "fr-FR", ttsCode: "fr-FR"),
        Language(code: "de", displayName: "Deutsch", speechCode: "de-DE", ttsCode: "de-DE"),
        Language(code: "ja", displayName: "日本語", speechCode: "ja-JP", ttsCode: "ja-JP"),
        Language(code: "zh", displayName: "中文", speechCode: "zh-CN", ttsCode: "zh-CN"),
        Language(code: "ko", displayName: "한국어", speechCode: "ko-KR", ttsCode: "ko-KR")
    ]

    init(currentLanguage: Language, apiKeys: [String: String]) {
        self.selectedLanguage = currentLanguage
        self.apiKeys = apiKeys

        // Load saved TTS settings
        if let savedProvider = UserDefaults.standard.string(forKey: "selectedTTSProvider"),
           let provider = TTSProvider(rawValue: savedProvider) {
            self.selectedTTSProvider = provider
        } else {
            self.selectedTTSProvider = .native
        }

        self.selectedVoiceId = UserDefaults.standard.string(forKey: "selectedTTSVoiceId")

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationBar()
        setupTableView()
        updateColors()
    }

    private func setupNavigationBar() {
        title = "Settings"

        let closeButton = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(closeTapped)
        )
        navigationItem.rightBarButtonItem = closeButton
    }

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(ExpandableHeaderView.self, forHeaderFooterViewReuseIdentifier: "Header")

        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func updateColors() {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark

        // Update view and table background
        if isDarkMode {
            view.backgroundColor = UIColor(white: 0.0, alpha: 1.0)
            tableView.backgroundColor = UIColor(white: 0.0, alpha: 1.0)
        } else {
            view.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
            tableView.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        }

        // Update navigation bar
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()

        if isDarkMode {
            appearance.backgroundColor = UIColor(white: 0.0, alpha: 1.0)
            appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
            appearance.shadowColor = UIColor(white: 0.2, alpha: 0.3)
            navigationItem.rightBarButtonItem?.tintColor = .white
        } else {
            appearance.backgroundColor = UIColor(white: 1.0, alpha: 1.0)
            appearance.titleTextAttributes = [.foregroundColor: UIColor.black]
            appearance.shadowColor = UIColor(white: 0.8, alpha: 0.3)
            navigationItem.rightBarButtonItem?.tintColor = .black
        }

        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance

        // Reload table to update cell colors
        tableView.reloadData()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors()
        }
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func handleSectionTap(_ sender: UITapGestureRecognizer) {
        guard let section = sender.view?.tag else { return }

        if expandedSections.contains(section) {
            expandedSections.remove(section)
        } else {
            expandedSections.insert(section)
        }

        tableView.reloadSections(IndexSet(integer: section), with: .automatic)

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }

    static func getCurrentLanguage() -> Language {
        let savedCode = UserDefaults.standard.string(forKey: "selectedLanguageCode") ?? "en"
        return languages.first(where: { $0.code == savedCode }) ?? languages[0]
    }

    private func showVoiceDownloadAlert(language: String) {
        let alert = UIAlertController(
            title: "Voice Not Available",
            message: "No iOS voices are installed for \(language).\n\nTo download voices:\n1. Open Settings app\n2. Go to Accessibility → Spoken Content → Voices\n3. Select \(language) and download a voice",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })

        alert.addAction(UIAlertAction(title: "OK", style: .cancel))

        present(alert, animated: true)
    }

    private func showElevenLabsLanguageAlert(language: String) {
        let baseLanguageCode = String(selectedLanguage.ttsCode.prefix(2))

        let message: String
        let switchAction: String

        if baseLanguageCode == "th" {
            // Thai-specific message
            message = "ElevenLabs doesn't support Thai language.\n\nFor Thai, please use:\n• BOTNOI Voice (Best for Thai)\n• iOS System Voices"
            switchAction = "Switch to BOTNOI"
        } else {
            // Generic message for other unsupported languages
            message = "ElevenLabs doesn't have voices optimized for \(language).\n\nRecommended:\n• iOS System Voices\n• Try English voices (may work with accent)"
            switchAction = "Switch to iOS"
        }

        let alert = UIAlertController(
            title: "Language Not Supported",
            message: message,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: switchAction, style: .default) { [weak self] _ in
            let newProvider: TTSProvider = baseLanguageCode == "th" ? .botnoi : .native
            self?.selectedTTSProvider = newProvider
            UserDefaults.standard.set(newProvider.rawValue, forKey: "selectedTTSProvider")
            self?.tableView.reloadSections(IndexSet(integer: 1), with: .automatic)
            self?.delegate?.settingsDidChangeTTSProvider(newProvider, voiceId: nil)
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        present(alert, animated: true)
    }

    private func showBotnoiLanguageAlert(language: String) {
        let alert = UIAlertController(
            title: "Thai Language Only",
            message: "BOTNOI Voice is optimized for Thai language only.\n\nFor \(language), please use:\n• iOS (System voices)\n• ElevenLabs (Multilingual support)",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Switch to iOS", style: .default) { [weak self] _ in
            self?.selectedTTSProvider = .native
            UserDefaults.standard.set(TTSProvider.native.rawValue, forKey: "selectedTTSProvider")
            self?.tableView.reloadSections(IndexSet(integer: 1), with: .automatic)
            self?.delegate?.settingsDidChangeTTSProvider(.native, voiceId: nil)
        })

        alert.addAction(UIAlertAction(title: "OK", style: .cancel))

        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource
extension SettingsViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return SettingsSection.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let settingsSection = SettingsSection(rawValue: section) else { return 0 }

        // Only show rows if section is expanded
        if !expandedSections.contains(section) {
            return 0
        }

        switch settingsSection {
        case .language:
            return Self.languages.count
        case .ttsProvider:
            // Count providers + voices for selected provider
            var count = TTSProvider.allCases.count
            count += getVoicesForProvider(selectedTTSProvider).count
            return count
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        guard let section = SettingsSection(rawValue: indexPath.section) else { return cell }

        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        cell.backgroundColor = isDarkMode ? UIColor(white: 0.11, alpha: 1.0) : .white
        cell.textLabel?.textColor = isDarkMode ? .white : .black

        switch section {
        case .language:
            let language = Self.languages[indexPath.row]
            cell.textLabel?.text = language.displayName
            cell.accessoryType = (language.code == selectedLanguage.code) ? .checkmark : .none
            cell.tintColor = .systemBlue

        case .ttsProvider:
            let providers = TTSProvider.allCases
            var currentRow = 0
            var foundMatch = false

            // Iterate through providers and their voices
            for provider in providers {
                if currentRow == indexPath.row {
                    // This is a provider row
                    cell.textLabel?.text = provider.displayName
                    cell.textLabel?.font = .systemFont(ofSize: 16, weight: .regular)
                    cell.accessoryType = (provider == selectedTTSProvider) ? .checkmark : .none
                    cell.tintColor = .systemBlue
                    foundMatch = true
                    break
                }
                currentRow += 1

                // If this provider is selected, show its voices
                if provider == selectedTTSProvider {
                    let voices = getVoicesForProvider(provider)
                    for voice in voices {
                        if currentRow == indexPath.row {
                            // This is a voice row (indented and styled differently)
                            cell.textLabel?.text = "    \(voice.name)"
                            cell.textLabel?.font = .systemFont(ofSize: 15)
                            cell.accessoryType = (voice.id == selectedVoiceId) ? .checkmark : .none
                            cell.tintColor = .systemGreen

                            // Make voice rows look more distinct
                            let isDarkMode = traitCollection.userInterfaceStyle == .dark
                            cell.backgroundColor = isDarkMode ? UIColor(white: 0.08, alpha: 1.0) : UIColor(white: 0.97, alpha: 1.0)
                            foundMatch = true
                            break
                        }
                        currentRow += 1
                    }
                    if foundMatch { break }
                }
            }
        }

        return cell
    }

    private func getVoicesForProvider(_ provider: TTSProvider) -> [TTSVoice] {
        switch provider {
        case .native:
            // Get high-quality iOS system voices for the selected language
            let allVoices = AVSpeechSynthesisVoice.speechVoices()
            let currentLanguageCode = selectedLanguage.ttsCode // e.g., "en-US", "th-TH"
            let languagePrefix = String(currentLanguageCode.prefix(2)) // e.g., "en", "th"

            // Filter for voices matching the selected language
            let languageMatchingVoices = allVoices.filter { voice in
                voice.language.hasPrefix(languagePrefix)
            }

            // If no voices found for this language, show alert to user
            if languageMatchingVoices.isEmpty {
                DispatchQueue.main.async { [weak self] in
                    self?.showVoiceDownloadAlert(language: self?.selectedLanguage.displayName ?? "this language")
                }
                // Return placeholder item
                return [TTSVoice(id: "download_required", name: "⚠️ Download voices from iOS Settings", provider: .native)]
            }

            // Further filter for enhanced quality voices
            let enhancedVoices = languageMatchingVoices.filter { voice in
                if #available(iOS 16.0, *) {
                    return voice.quality == .enhanced || voice.quality == .premium
                } else {
                    return voice.quality == .enhanced
                }
            }

            // If no enhanced voices for this language, use default quality
            let voicesToUse = enhancedVoices.isEmpty ? languageMatchingVoices : enhancedVoices

            // Sort by quality (enhanced/premium first) and then by name
            let sortedVoices = voicesToUse.sorted { voice1, voice2 in
                if #available(iOS 16.0, *) {
                    let quality1 = voice1.quality == .premium ? 3 : (voice1.quality == .enhanced ? 2 : 1)
                    let quality2 = voice2.quality == .premium ? 3 : (voice2.quality == .enhanced ? 2 : 1)
                    if quality1 != quality2 {
                        return quality1 > quality2
                    }
                } else {
                    let quality1 = voice1.quality == .enhanced ? 2 : 1
                    let quality2 = voice2.quality == .enhanced ? 2 : 1
                    if quality1 != quality2 {
                        return quality1 > quality2
                    }
                }
                return voice1.name < voice2.name
            }

            // Convert to TTSVoice
            return sortedVoices.map { voice in
                let qualityBadge: String
                if #available(iOS 16.0, *) {
                    qualityBadge = voice.quality == .premium ? " ⭐️" : (voice.quality == .enhanced ? " ✨" : "")
                } else {
                    qualityBadge = voice.quality == .enhanced ? " ✨" : ""
                }
                let displayName = "\(voice.name)\(qualityBadge)"
                return TTSVoice(id: voice.identifier, name: displayName, provider: .native)
            }

        case .elevenlabs:
            if let apiKey = apiKeys["elevenlabs"] {
                // Create or reuse cached manager
                if elevenLabsManager == nil {
                    elevenLabsManager = ElevenLabsTTSManager(apiKey: apiKey)

                    // Only fetch from API once when first created
                    elevenLabsManager?.fetchVoicesFromAPI { [weak self] fetchedVoices in
                        print("✅ ElevenLabs voices fetched: \(fetchedVoices.count)")
                        // Refresh the voice list in the UI ONLY on first fetch
                        DispatchQueue.main.async {
                            if let self = self, self.selectedTTSProvider == .elevenlabs {
                                self.tableView.reloadSections(IndexSet(integer: 1), with: .automatic)
                            }
                        }
                    }
                }
                guard let manager = elevenLabsManager else { return [] }

                let currentLanguageCode = selectedLanguage.ttsCode // e.g., "en-US", "th-TH"

                // Get voices filtered by language (uses cached data after first fetch)
                let voices = manager.getAvailableVoices(forLanguage: currentLanguageCode)

                // If no exact matches, show all voices as fallback
                if voices.isEmpty {
                    print("ℹ️ No exact language match for \(currentLanguageCode), showing all ElevenLabs voices")
                    return manager.getAvailableVoices()
                }

                return voices
            }
        case .botnoi:
            if let apiKey = apiKeys["botnoi"] {
                // Create or reuse cached manager
                if botnoiManager == nil {
                    print("🔊 [BOTNOI] Creating new manager instance")
                    botnoiManager = BotnoiTTSManager(apiKey: apiKey)

                    // Only fetch from API once when first created
                    let currentLanguageCode = selectedLanguage.ttsCode
                    botnoiManager?.fetchVoicesFromAPI { [weak self] fetchedVoices in
                        print("✅ BOTNOI speakers fetched: \(fetchedVoices.count)")
                        // Refresh the voice list in the UI ONLY on first fetch
                        DispatchQueue.main.async {
                            if let self = self, self.selectedTTSProvider == .botnoi {
                                print("🔄 [BOTNOI] Reloading table with fetched voices")
                                self.tableView.reloadSections(IndexSet(integer: 1), with: .automatic)
                            }
                        }
                    }
                }
                guard let manager = botnoiManager else { return [] }

                let currentLanguageCode = selectedLanguage.ttsCode // e.g., "en-US", "th-TH"

                // Get voices filtered by language (uses cached data after first fetch)
                let voices = manager.getAvailableVoices(forLanguage: currentLanguageCode)

                // If no voices available for this language, show alert
                if voices.isEmpty {
                    DispatchQueue.main.async { [weak self] in
                        self?.showBotnoiLanguageAlert(language: self?.selectedLanguage.displayName ?? "this language")
                    }
                    return [TTSVoice(id: "thai_only", name: "⚠️ BOTNOI Voice only supports Thai", provider: .botnoi)]
                }

                return voices
            }
        }
        return []
    }
}

// MARK: - UITableViewDelegate
extension SettingsViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let settingsSection = SettingsSection(rawValue: section),
              let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "Header") as? ExpandableHeaderView else {
            return nil
        }

        let isExpanded = expandedSections.contains(section)
        let currentValue: String

        switch settingsSection {
        case .language:
            currentValue = selectedLanguage.displayName
        case .ttsProvider:
            currentValue = selectedTTSProvider.displayName
        }

        headerView.configure(title: settingsSection.title, value: currentValue, isExpanded: isExpanded)
        headerView.tag = section

        // Remove old gesture recognizers
        headerView.gestureRecognizers?.forEach { headerView.removeGestureRecognizer($0) }

        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleSectionTap(_:)))
        headerView.addGestureRecognizer(tapGesture)

        return headerView
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 50
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let section = SettingsSection(rawValue: indexPath.section) else { return }

        switch section {
        case .language:
            let language = Self.languages[indexPath.row]
            selectedLanguage = language

            UserDefaults.standard.set(language.code, forKey: "selectedLanguageCode")
            delegate?.settingsDidChangeLanguage(language)

            // Reload both sections: language AND TTS provider (because iOS voices change with language)
            tableView.reloadSections(IndexSet(integersIn: 0...1), with: .none)

        case .ttsProvider:
            let providers = TTSProvider.allCases
            var currentRow = 0

            // Find what was tapped
            for provider in providers {
                if currentRow == indexPath.row {
                    // Tapped a provider
                    selectedTTSProvider = provider
                    selectedVoiceId = nil // Reset voice when changing provider

                    delegate?.settingsDidChangeTTSProvider(provider, voiceId: nil)
                    tableView.reloadSections(IndexSet(integer: indexPath.section), with: .automatic)
                    return
                }
                currentRow += 1

                // Check voices for selected provider
                if provider == selectedTTSProvider {
                    let voices = getVoicesForProvider(provider)
                    for voice in voices {
                        if currentRow == indexPath.row {
                            // Tapped a voice
                            selectedVoiceId = voice.id
                            delegate?.settingsDidChangeTTSProvider(selectedTTSProvider, voiceId: voice.id)
                            tableView.reloadSections(IndexSet(integer: indexPath.section), with: .none)
                            return
                        }
                        currentRow += 1
                    }
                }
            }
        }

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - Expandable Header View
class ExpandableHeaderView: UITableViewHeaderFooterView {

    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let chevronImageView = UIImageView()

    override init(reuseIdentifier: String?) {
        super.init(reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        valueLabel.font = .systemFont(ofSize: 14)
        chevronImageView.image = UIImage(systemName: "chevron.down")
        chevronImageView.contentMode = .scaleAspectFit

        updateColors()

        contentView.addSubview(titleLabel)
        contentView.addSubview(valueLabel)
        contentView.addSubview(chevronImageView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        chevronImageView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            valueLabel.trailingAnchor.constraint(equalTo: chevronImageView.leadingAnchor, constant: -8),
            valueLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            chevronImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            chevronImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            chevronImageView.widthAnchor.constraint(equalToConstant: 20),
            chevronImageView.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    func configure(title: String, value: String, isExpanded: Bool) {
        titleLabel.text = title
        valueLabel.text = value

        // Rotate chevron
        UIView.animate(withDuration: 0.3) {
            self.chevronImageView.transform = isExpanded ? CGAffineTransform(rotationAngle: .pi) : .identity
        }

        updateColors()
    }

    private func updateColors() {
        let isDarkMode = traitCollection.userInterfaceStyle == .dark

        if isDarkMode {
            contentView.backgroundColor = UIColor(white: 0.05, alpha: 1.0)
            titleLabel.textColor = .white
            valueLabel.textColor = UIColor(white: 0.6, alpha: 1.0)
            chevronImageView.tintColor = UIColor(white: 0.6, alpha: 1.0)
        } else {
            contentView.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
            titleLabel.textColor = .black
            valueLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
            chevronImageView.tintColor = UIColor(white: 0.5, alpha: 1.0)
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            updateColors()
        }
    }
}
