import UIKit

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

        view.backgroundColor = UIColor(white: 0.0, alpha: 1.0)

        setupNavigationBar()
        setupTableView()
    }

    private func setupNavigationBar() {
        title = "Settings"

        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(white: 0.0, alpha: 1.0)
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.shadowColor = UIColor(white: 0.2, alpha: 0.3)

        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance

        let closeButton = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(closeTapped)
        )
        closeButton.tintColor = .white
        navigationItem.rightBarButtonItem = closeButton
    }

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = UIColor(white: 0.0, alpha: 1.0)
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
            // Show provider options
            if selectedTTSProvider == .native {
                return TTSProvider.allCases.count
            } else {
                // Show providers + voices for selected provider
                return TTSProvider.allCases.count + getVoicesForProvider(selectedTTSProvider).count
            }
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        guard let section = SettingsSection(rawValue: indexPath.section) else { return cell }

        cell.backgroundColor = UIColor(white: 0.11, alpha: 1.0)
        cell.textLabel?.textColor = .white

        switch section {
        case .language:
            let language = Self.languages[indexPath.row]
            cell.textLabel?.text = language.displayName
            cell.accessoryType = (language.code == selectedLanguage.code) ? .checkmark : .none
            cell.tintColor = .systemBlue

        case .ttsProvider:
            let providers = TTSProvider.allCases
            if indexPath.row < providers.count {
                // Provider row
                let provider = providers[indexPath.row]
                cell.textLabel?.text = provider.displayName
                cell.accessoryType = (provider == selectedTTSProvider) ? .checkmark : .none
                cell.tintColor = .systemBlue
            } else {
                // Voice row (indented)
                let voiceIndex = indexPath.row - providers.count
                let voices = getVoicesForProvider(selectedTTSProvider)
                if voiceIndex < voices.count {
                    let voice = voices[voiceIndex]
                    cell.textLabel?.text = "    \(voice.name)" // Indented
                    cell.textLabel?.font = .systemFont(ofSize: 15)
                    cell.accessoryType = (voice.id == selectedVoiceId) ? .checkmark : .none
                    cell.tintColor = .systemGreen
                }
            }
        }

        return cell
    }

    private func getVoicesForProvider(_ provider: TTSProvider) -> [TTSVoice] {
        switch provider {
        case .elevenlabs:
            if let apiKey = apiKeys["elevenlabs"] {
                let manager = ElevenLabsTTSManager(apiKey: apiKey)
                return manager.getAvailableVoices()
            }
        case .botnoi:
            if let apiKey = apiKeys["botnoi"] {
                let manager = BotnoiTTSManager(apiKey: apiKey)
                return manager.getAvailableVoices()
            }
        case .native:
            break
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

            tableView.reloadSections(IndexSet(integer: indexPath.section), with: .none)

        case .ttsProvider:
            let providers = TTSProvider.allCases
            if indexPath.row < providers.count {
                // Selected a provider
                let provider = providers[indexPath.row]
                selectedTTSProvider = provider
                selectedVoiceId = nil // Reset voice when changing provider

                delegate?.settingsDidChangeTTSProvider(provider, voiceId: nil)

                tableView.reloadSections(IndexSet(integer: indexPath.section), with: .automatic)
            } else {
                // Selected a voice
                let voiceIndex = indexPath.row - providers.count
                let voices = getVoicesForProvider(selectedTTSProvider)
                if voiceIndex < voices.count {
                    let voice = voices[voiceIndex]
                    selectedVoiceId = voice.id

                    delegate?.settingsDidChangeTTSProvider(selectedTTSProvider, voiceId: voice.id)

                    tableView.reloadSections(IndexSet(integer: indexPath.section), with: .none)
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
        contentView.backgroundColor = UIColor(white: 0.05, alpha: 1.0)

        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = .white

        valueLabel.font = .systemFont(ofSize: 14)
        valueLabel.textColor = UIColor(white: 0.6, alpha: 1.0)

        chevronImageView.image = UIImage(systemName: "chevron.down")
        chevronImageView.tintColor = UIColor(white: 0.6, alpha: 1.0)
        chevronImageView.contentMode = .scaleAspectFit

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
    }
}
