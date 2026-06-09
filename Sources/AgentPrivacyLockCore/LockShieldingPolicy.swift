import AppKit

enum LockShieldingPolicy {
    static let overlayCollectionBehavior: NSWindow.CollectionBehavior = [
        .canJoinAllSpaces,
        .canJoinAllApplications,
        .fullScreenAuxiliary,
        .stationary,
        .ignoresCycle
    ]

    static let presentationOptions: NSApplication.PresentationOptions = [
        .disableProcessSwitching,
        .disableHideApplication,
        .disableSessionTermination
    ]
}
