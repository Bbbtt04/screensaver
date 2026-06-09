import Foundation

public struct AttemptLimiter: Sendable {
    public let maxFailuresBeforeDelay: Int
    public let delaySeconds: TimeInterval
    private var failedAttempts: Int
    private var delayedUntil: Date?

    public init(maxFailuresBeforeDelay: Int = 3, delaySeconds: TimeInterval = 30) {
        self.maxFailuresBeforeDelay = max(1, maxFailuresBeforeDelay)
        self.delaySeconds = max(0, delaySeconds)
        self.failedAttempts = 0
        self.delayedUntil = nil
    }

    public func nextAllowedAttempt(at now: Date = Date()) -> Date {
        guard let delayedUntil, delayedUntil > now else {
            return now
        }
        return delayedUntil
    }

    public mutating func recordFailure(at now: Date = Date()) {
        failedAttempts += 1
        if failedAttempts >= maxFailuresBeforeDelay {
            delayedUntil = now.addingTimeInterval(delaySeconds)
        }
    }

    public mutating func recordSuccess() {
        failedAttempts = 0
        delayedUntil = nil
    }
}
