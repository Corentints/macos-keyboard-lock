import CoreGraphics
import ApplicationServices

/// Swallows every keyboard event (keys, modifiers, media keys) through a session-wide event tap.
final class KeyboardBlocker {
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var isActive: Bool { tap != nil }

    /// NX_SYSDEFINED carries the media keys (volume, brightness, playback).
    private static let systemDefinedEvent = CGEventType(rawValue: 14)!

    private static var blockedEventMask: CGEventMask {
        let events: [CGEventType] = [.keyDown, .keyUp, .flagsChanged, systemDefinedEvent]
        return events.reduce(0) { $0 | (1 << $1.rawValue) }
    }

    static func isAccessibilityGranted(prompting: Bool) -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": prompting] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func start() throws {
        guard tap == nil else { return }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: Self.blockedEventMask,
            callback: Self.handleEvent,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { throw LockError.eventTapUnavailable }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.tap = tap
        runLoopSource = source
    }

    func stop() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        self.tap = nil
        runLoopSource = nil
    }

    deinit { stop() }

    private static let handleEvent: CGEventTapCallBack = { _, type, event, userInfo in
        guard type != .tapDisabledByTimeout, type != .tapDisabledByUserInput else {
            // The system disabled the tap (e.g. slow callback): turn it back on and let the event through.
            if let userInfo, let tap = Unmanaged<KeyboardBlocker>.fromOpaque(userInfo).takeUnretainedValue().tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }
        return nil // swallowed
    }
}
