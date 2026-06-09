import ApplicationServices
import AppKit
import Foundation

final class InputInterceptor {
    static let interceptedEventTypes: [CGEventType] = [
        .leftMouseDown,
        .leftMouseUp,
        .rightMouseDown,
        .rightMouseUp,
        .otherMouseDown,
        .otherMouseUp,
        .mouseMoved,
        .leftMouseDragged,
        .rightMouseDragged,
        .otherMouseDragged,
        .scrollWheel,
        .keyDown,
        CGEventType(rawValue: CGEventType.RawValue(NSEvent.EventType.rotate.rawValue)),
        CGEventType(rawValue: CGEventType.RawValue(NSEvent.EventType.gesture.rawValue)),
        CGEventType(rawValue: CGEventType.RawValue(NSEvent.EventType.magnify.rawValue)),
        CGEventType(rawValue: CGEventType.RawValue(NSEvent.EventType.swipe.rawValue))
    ].compactMap { $0 }

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func start() -> Bool {
        let mask = Self.interceptedEventTypes.reduce(CGEventMask(0)) { partial, type in
            partial | CGEventMask(1 << type.rawValue)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, _ in
                switch type {
                case .keyDown:
                    let flags = event.flags
                    if flags.contains(.maskCommand) || flags.contains(.maskAlternate) || flags.contains(.maskControl) {
                        return nil
                    }
                    return Unmanaged.passUnretained(event)
                default:
                    return nil
                }
            },
            userInfo: nil
        ) else {
            return false
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        runLoopSource = nil
        eventTap = nil
    }
}
