import Foundation

public struct LockStatus: Sendable {
    public let startedAt: Date
    public let taskLabel: String

    public init(startedAt: Date = Date(), taskLabel: String = "Background agent task") {
        self.startedAt = startedAt
        self.taskLabel = taskLabel
    }

    public func displayLines(now: Date = Date()) -> [String] {
        [
            ClientCopy.appName,
            "任务：\(taskLabel)",
            "已锁定：\(Self.formatElapsed(now.timeIntervalSince(startedAt)))"
        ]
    }

    private static func formatElapsed(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded(.down)))
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, remainingSeconds)
    }
}
