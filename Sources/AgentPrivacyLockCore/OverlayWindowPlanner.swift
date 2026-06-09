import Foundation

public struct OverlayWindowPlan<ScreenID: Equatable & Sendable>: Equatable, Sendable {
    public let screenID: ScreenID
    public let isPrimary: Bool

    public var showsUnlockControls: Bool {
        isPrimary
    }
}

public enum OverlayWindowPlanner {
    public static func plans<ScreenID: Equatable & Sendable>(
        screenIDs: [ScreenID],
        mainScreenID: ScreenID?
    ) -> [OverlayWindowPlan<ScreenID>] {
        let fallbackPrimary = screenIDs.first
        return screenIDs.map { screenID in
            OverlayWindowPlan(
                screenID: screenID,
                isPrimary: screenID == (mainScreenID ?? fallbackPrimary)
            )
        }
    }
}
