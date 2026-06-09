import Foundation

public enum CaffeinatePolicy: String, CaseIterable, Sendable {
    case full

    public var arguments: [String] {
        ["-d", "-i", "-m", "-s"]
    }
}
