import Capacitor
import UIKit

@objc(ChatComposerPlugin)
public class ChatComposerPlugin: CAPPlugin, CAPBridgedPlugin {
    public let identifier = "ChatComposerPlugin"
    public let jsName = "ChatComposer"
    public let pluginMethods: [CAPPluginMethod] = [
        CAPPluginMethod(name: "show", returnType: CAPPluginReturnPromise),
        CAPPluginMethod(name: "hide", returnType: CAPPluginReturnPromise)
    ]

    private var composerVC: ChatComposerViewController?

    @objc public func show(_ call: CAPPluginCall) {
        NSLog("🔥 ChatComposer.show() CALLED")
        DispatchQueue.main.async {
            guard let bridgeVC = self.bridge?.viewController else {
                NSLog("ChatComposerPlugin: bridge viewController missing")
                call.resolve()
                return
            }

            if self.composerVC == nil {
                NSLog("ChatComposerPlugin: creating composer view")
                let composer = ChatComposerViewController()
                composer.onSend = { message in
                    self.notifyWeb(message: message)
                }
                composer.onVoiceToggle = {
                    self.notifyListeners("voiceToggle", data: [:])
                }

                self.composerVC = composer
                bridgeVC.addChild(composer)
                bridgeVC.view.addSubview(composer.view)
                composer.didMove(toParent: bridgeVC)

                composer.view.translatesAutoresizingMaskIntoConstraints = false

                let keyboardGuide = bridgeVC.view.keyboardLayoutGuide
                NSLayoutConstraint.activate([
                    composer.view.leadingAnchor.constraint(equalTo: bridgeVC.view.leadingAnchor),
                    composer.view.trailingAnchor.constraint(equalTo: bridgeVC.view.trailingAnchor),
                    composer.view.bottomAnchor.constraint(equalTo: keyboardGuide.topAnchor),
                    composer.view.heightAnchor.constraint(greaterThanOrEqualToConstant: 64)
                ])

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NSLog("ChatComposerPlugin: focusing input")
                    bridgeVC.view.window?.makeKeyAndVisible()
                    bridgeVC.view.endEditing(true)
                    bridgeVC.view.bringSubviewToFront(composer.view)
                    composer.focusInput()
                }
            } else {
                NSLog("ChatComposerPlugin: showing existing composer view")
                self.composerVC?.view.isHidden = false
                bridgeVC.view.window?.makeKeyAndVisible()
                bridgeVC.view.endEditing(true)
                if let composerView = self.composerVC?.view {
                    bridgeVC.view.bringSubviewToFront(composerView)
                }
                self.composerVC?.focusInput()
            }

            call.resolve()
        }
    }

    @objc public func hide(_ call: CAPPluginCall) {
        DispatchQueue.main.async {
            self.composerVC?.view.isHidden = true
            self.composerVC?.view.endEditing(true)
            call.resolve()
        }
    }

    private func notifyWeb(message: String) {
        self.notifyListeners("messageSend", data: ["text": message])
    }
}
