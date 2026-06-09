import Foundation

public struct PetLoadingFrame: Equatable, Sendable {
    public let elapsed: TimeInterval
    public let step: Int

    public init(elapsed: TimeInterval) {
        self.elapsed = max(0, elapsed)
        self.step = Int((self.elapsed * 4).rounded(.down)) % 4
    }

    public var dotCount: Int {
        step + 1
    }

    public var pawOffset: Double {
        switch step {
        case 0:
            return 0
        case 1:
            return 4
        case 2:
            return 0
        default:
            return -4
        }
    }

    public var earOffset: Double {
        step == 1 || step == 2 ? 2 : 0
    }

    public var statusText: String {
        "Claude 小宠物正在干活\(String(repeating: ".", count: dotCount))"
    }
}
