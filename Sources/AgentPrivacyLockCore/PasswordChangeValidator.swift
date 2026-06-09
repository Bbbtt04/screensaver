import Foundation

public enum PasswordChangeValidationResult: Equatable, Sendable {
    case valid
    case empty
    case defaultPassword
    case mismatch
}

public enum PasswordChangeValidator {
    public static func validate(password: String, confirmation: String) -> PasswordChangeValidationResult {
        guard !password.isEmpty else {
            return .empty
        }
        guard password != PasswordStore.defaultUnlockPassword else {
            return .defaultPassword
        }
        guard password == confirmation else {
            return .mismatch
        }
        return .valid
    }
}
