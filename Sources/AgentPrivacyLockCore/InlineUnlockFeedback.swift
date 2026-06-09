import AppKit

@MainActor
final class InlineUnlockFeedback {
    private weak var passwordField: NSSecureTextField?
    private weak var messageLabel: NSTextField?

    init(passwordField: NSSecureTextField, messageLabel: NSTextField) {
        self.passwordField = passwordField
        self.messageLabel = messageLabel
    }

    func show(_ message: String) {
        passwordField?.stringValue = ""
        messageLabel?.stringValue = message
        messageLabel?.isHidden = false

        if let passwordField {
            passwordField.window?.makeFirstResponder(passwordField)
        }
    }

    func clear() {
        messageLabel?.stringValue = ""
        messageLabel?.isHidden = true
    }
}
