import UIKit

class ChatComposerViewController: UIViewController, UITextViewDelegate {

    var onSend: ((String) -> Void)?
    var onVoiceToggle: (() -> Void)?

    private let container = UIView()
    private let input = UITextView()
    private let sendButton = UIButton(type: .system)
    private let micButton = UIButton(type: .system)
    private var isInVoiceMode = false

    override func viewDidLoad() {
        super.viewDidLoad()

        // ChatGPT-style dark composer
        view.backgroundColor = UIColor(white: 0.0, alpha: 1.0)

        container.backgroundColor = UIColor(white: 0.11, alpha: 1.0) // #1C1C1E
        container.layer.cornerRadius = 24
        container.layer.cornerCurve = .continuous

        input.font = .systemFont(ofSize: 16)
        input.textContainerInset = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        input.backgroundColor = .clear
        input.textColor = .white
        input.tintColor = .white
        input.isScrollEnabled = false
        input.delegate = self

        // Placeholder-like behavior
        if input.text.isEmpty {
            input.text = "Ask anything"
            input.textColor = UIColor(white: 0.5, alpha: 1.0)
        }

        sendButton.setImage(UIImage(systemName: "arrow.up.circle.fill"), for: .normal)
        sendButton.tintColor = UIColor(white: 0.5, alpha: 1.0)
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        sendButton.isHidden = true // Show only when typing

        micButton.setImage(UIImage(systemName: "mic.fill"), for: .normal)
        micButton.tintColor = .white
        micButton.addTarget(self, action: #selector(voiceTapped), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [input, sendButton, micButton])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8

        container.addSubview(stack)
        view.addSubview(container)

        container.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        input.translatesAutoresizingMaskIntoConstraints = false
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        micButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            container.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            container.heightAnchor.constraint(equalToConstant: 50),

            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            input.heightAnchor.constraint(greaterThanOrEqualToConstant: 40),
            sendButton.widthAnchor.constraint(equalToConstant: 32),
            sendButton.heightAnchor.constraint(equalToConstant: 32),
            micButton.widthAnchor.constraint(equalToConstant: 32),
            micButton.heightAnchor.constraint(equalToConstant: 32)
        ])
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.text == "Ask anything" {
            textView.text = ""
            textView.textColor = .white
        }
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty {
            textView.text = "Ask anything"
            textView.textColor = UIColor(white: 0.5, alpha: 1.0)
        }
    }

    func textViewDidChange(_ textView: UITextView) {
        // Don't change buttons in voice mode
        guard !isInVoiceMode else { return }

        // Show send button when typing, hide mic
        let hasText = !textView.text.isEmpty && textView.text != "Ask anything"
        sendButton.isHidden = !hasText
        micButton.isHidden = hasText
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Don't auto-focus on appear - let user tap to focus
        // input.becomeFirstResponder()
    }

    func focusInput() {
        input.becomeFirstResponder()
    }

    @objc private func sendTapped() {
        let text = input.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty && text != "Ask anything" else { return }
        onSend?(text)
        input.text = "Ask anything"
        input.textColor = UIColor(white: 0.5, alpha: 1.0)
        sendButton.isHidden = true
        micButton.isHidden = false
    }

    @objc private func voiceTapped() {
        onVoiceToggle?()
    }

    // MARK: - Voice Mode Control
    func setVoiceMode(_ enabled: Bool) {
        isInVoiceMode = enabled

        if enabled {
            // Change mic to stop icon
            micButton.setImage(UIImage(systemName: "stop.circle.fill"), for: .normal)
            micButton.tintColor = .white

            // Disable text editing
            input.isEditable = false
            input.textColor = UIColor(white: 0.7, alpha: 1.0)

            // Hide send button
            sendButton.isHidden = true
            micButton.isHidden = false
        } else {
            // Change back to mic icon
            micButton.setImage(UIImage(systemName: "mic.fill"), for: .normal)
            micButton.tintColor = .white

            // Enable text editing
            input.isEditable = true
            input.textColor = .white

            // Reset placeholder
            if input.text.isEmpty {
                input.text = "Ask anything"
                input.textColor = UIColor(white: 0.5, alpha: 1.0)
            }
        }
    }

    func updateInput(_ text: String) {
        input.text = text
        input.textColor = .white
    }

    func clearInput() {
        input.text = ""
        input.textColor = UIColor(white: 0.5, alpha: 1.0)
    }
}
