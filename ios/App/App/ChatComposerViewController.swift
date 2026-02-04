import UIKit

class ChatComposerViewController: UIViewController, UITextViewDelegate {

    var onSend: ((String) -> Void)?
    var onVoiceToggle: (() -> Void)?

    private let container = UIView()
    private let input = UITextView()
    private let sendButton = UIButton(type: .system)
    private let micButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear

        container.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        container.layer.cornerRadius = 16
        container.layer.cornerCurve = .continuous
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.08
        container.layer.shadowRadius = 16
        container.layer.shadowOffset = CGSize(width: 0, height: -6)

        input.font = .systemFont(ofSize: 16)
        input.textContainerInset = UIEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        input.backgroundColor = UIColor.secondarySystemBackground
        input.layer.cornerRadius = 14
        input.isScrollEnabled = false
        input.delegate = self

        sendButton.setImage(UIImage(systemName: "paperplane.fill"), for: .normal)
        sendButton.tintColor = .label
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)

        micButton.setImage(UIImage(systemName: "mic.fill"), for: .normal)
        micButton.tintColor = .label
        micButton.addTarget(self, action: #selector(voiceTapped), for: .touchUpInside)

        let buttonStack = UIStackView(arrangedSubviews: [sendButton, micButton])
        buttonStack.axis = .horizontal
        buttonStack.alignment = .center
        buttonStack.spacing = 8

        let stack = UIStackView(arrangedSubviews: [input, buttonStack])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 10

        container.addSubview(stack)
        view.addSubview(container)

        container.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        input.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            container.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),

            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),

            input.heightAnchor.constraint(greaterThanOrEqualToConstant: 36),
            sendButton.widthAnchor.constraint(equalToConstant: 34),
            sendButton.heightAnchor.constraint(equalToConstant: 34),
            micButton.widthAnchor.constraint(equalToConstant: 34),
            micButton.heightAnchor.constraint(equalToConstant: 34)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        input.becomeFirstResponder()
    }

    func focusInput() {
        input.becomeFirstResponder()
    }

    @objc private func sendTapped() {
        let text = input.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        onSend?(text)
        input.text = ""
    }

    @objc private func voiceTapped() {
        onVoiceToggle?()
    }
}
