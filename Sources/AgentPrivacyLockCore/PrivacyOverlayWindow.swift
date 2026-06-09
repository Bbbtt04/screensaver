import AppKit

@MainActor
public final class PrivacyOverlayWindow: NSWindow {
    public override var canBecomeKey: Bool {
        true
    }

    public override var canBecomeMain: Bool {
        true
    }
}
