import AppKit
import Carbon.HIToolbox
import Foundation

public struct HotKeyConfig: Sendable, Codable, Equatable {
    public let keyCode: UInt16
    public let modifierFlags: UInt  // NSEvent.ModifierFlags.rawValue

    public init(keyCode: UInt16, modifierFlags: UInt) {
        self.keyCode = keyCode
        self.modifierFlags = modifierFlags
    }

    public static let `default` = HotKeyConfig(
        keyCode: UInt16(kVK_ANSI_B),
        modifierFlags: NSEvent.ModifierFlags([.command, .control]).rawValue
    )

    public var displayString: String {
        let flags = NSEvent.ModifierFlags(rawValue: modifierFlags)
        var result = ""
        if flags.contains(.control) { result += "⌃" }
        if flags.contains(.option) { result += "⌥" }
        if flags.contains(.shift) { result += "⇧" }
        if flags.contains(.command) { result += "⌘" }
        result += keyName
        return result
    }

    var carbonModifiers: UInt32 {
        let flags = NSEvent.ModifierFlags(rawValue: modifierFlags)
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        return result
    }

    private var keyName: String {
        switch Int(keyCode) {
        case kVK_ANSI_A: "A"; case kVK_ANSI_B: "B"; case kVK_ANSI_C: "C"
        case kVK_ANSI_D: "D"; case kVK_ANSI_E: "E"; case kVK_ANSI_F: "F"
        case kVK_ANSI_G: "G"; case kVK_ANSI_H: "H"; case kVK_ANSI_I: "I"
        case kVK_ANSI_J: "J"; case kVK_ANSI_K: "K"; case kVK_ANSI_L: "L"
        case kVK_ANSI_M: "M"; case kVK_ANSI_N: "N"; case kVK_ANSI_O: "O"
        case kVK_ANSI_P: "P"; case kVK_ANSI_Q: "Q"; case kVK_ANSI_R: "R"
        case kVK_ANSI_S: "S"; case kVK_ANSI_T: "T"; case kVK_ANSI_U: "U"
        case kVK_ANSI_V: "V"; case kVK_ANSI_W: "W"; case kVK_ANSI_X: "X"
        case kVK_ANSI_Y: "Y"; case kVK_ANSI_Z: "Z"
        case kVK_ANSI_0: "0"; case kVK_ANSI_1: "1"; case kVK_ANSI_2: "2"
        case kVK_ANSI_3: "3"; case kVK_ANSI_4: "4"; case kVK_ANSI_5: "5"
        case kVK_ANSI_6: "6"; case kVK_ANSI_7: "7"; case kVK_ANSI_8: "8"
        case kVK_ANSI_9: "9"
        case kVK_F1: "F1"; case kVK_F2: "F2"; case kVK_F3: "F3"
        case kVK_F4: "F4"; case kVK_F5: "F5"; case kVK_F6: "F6"
        case kVK_F7: "F7"; case kVK_F8: "F8"; case kVK_F9: "F9"
        case kVK_F10: "F10"; case kVK_F11: "F11"; case kVK_F12: "F12"
        case kVK_Space: "Space"
        default: "Key(\(keyCode))"
        }
    }
}

// C-compatible callback — no captures allowed; uses the static `fireAction`.
private func hotKeyEventCallback(
    _ callRef: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    GlobalHotKeyRegistrar.fireAction?()
    return OSStatus(noErr)
}

@MainActor
public final class GlobalHotKeyRegistrar {
    /// Stores the pending action; accessed only on the main thread.
    nonisolated(unsafe) static var fireAction: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    public init() {}

    public func register(_ config: HotKeyConfig, action: @escaping @MainActor () -> Void) {
        unregister()

        Self.fireAction = { Task { @MainActor in action() } }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventCallback,
            1, &eventType, nil, &eventHandlerRef
        )

        let hotKeyID = EventHotKeyID(signature: aplkFourCC, id: 1)
        RegisterEventHotKey(
            UInt32(config.keyCode),
            config.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            OptionBits(0),
            &hotKeyRef
        )
    }

    public func unregister() {
        Self.fireAction = nil
        if let ref = hotKeyRef { UnregisterEventHotKey(ref); hotKeyRef = nil }
        if let ref = eventHandlerRef { RemoveEventHandler(ref); eventHandlerRef = nil }
    }
}

private let aplkFourCC: FourCharCode = {
    "APLK".unicodeScalars.reduce(FourCharCode(0)) { ($0 << 8) | FourCharCode($1.value) }
}()
