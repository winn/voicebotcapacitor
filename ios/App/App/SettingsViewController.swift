import UIKit

protocol SettingsViewControllerDelegate: AnyObject {
    func settingsDidChangeLanguage(_ language: Language)
}

struct Language {
    let code: String
    let displayName: String
    let speechCode: String // For SFSpeechRecognizer
    let ttsCode: String // For AVSpeechSynthesisVoice
}

class SettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    weak var delegate: SettingsViewControllerDelegate?

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var selectedLanguage: Language

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

    init(currentLanguage: Language) {
        self.selectedLanguage = currentLanguage
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

        // ChatGPT-style dark navigation bar
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(white: 0.0, alpha: 1.0)
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.shadowColor = UIColor(white: 0.2, alpha: 0.3)

        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance

        // Close button
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
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "LanguageCell")

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

    // MARK: - UITableViewDataSource
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Self.languages.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "LanguageCell", for: indexPath)
        let language = Self.languages[indexPath.row]

        cell.textLabel?.text = language.displayName
        cell.textLabel?.textColor = .white
        cell.backgroundColor = UIColor(white: 0.11, alpha: 1.0)

        // Show checkmark for selected language
        if language.code == selectedLanguage.code {
            cell.accessoryType = .checkmark
            cell.tintColor = .systemBlue
        } else {
            cell.accessoryType = .none
        }

        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Language"
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.textColor = UIColor(white: 0.6, alpha: 1.0)
        }
    }

    // MARK: - UITableViewDelegate
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let language = Self.languages[indexPath.row]

        // Update selection
        selectedLanguage = language

        // Save to UserDefaults
        UserDefaults.standard.set(language.code, forKey: "selectedLanguageCode")

        // Reload table to update checkmarks
        tableView.reloadData()

        // Notify delegate
        delegate?.settingsDidChangeLanguage(language)

        // Show feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        print("✅ [SETTINGS] Language changed to: \(language.displayName)")
    }

    // MARK: - Helper
    static func getCurrentLanguage() -> Language {
        let savedCode = UserDefaults.standard.string(forKey: "selectedLanguageCode") ?? "en"
        return languages.first(where: { $0.code == savedCode }) ?? languages[0]
    }
}
