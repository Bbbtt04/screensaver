import Foundation

public struct LockConfiguration: Sendable {
    public let passwordRecord: PasswordRecord
    public let taskLabel: String
    public let caffeinatePolicy: CaffeinatePolicy

    public init(
        passwordRecord: PasswordRecord,
        taskLabel: String = "Background agent task",
        caffeinatePolicy: CaffeinatePolicy = .full
    ) {
        self.passwordRecord = passwordRecord
        self.taskLabel = taskLabel
        self.caffeinatePolicy = caffeinatePolicy
    }
}
