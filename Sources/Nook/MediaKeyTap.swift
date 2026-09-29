import AppKit
import os

let keyLog = Logger(subsystem: "com.mattiasandersson.nook", category: "keys")

/// Intercepts the hardware volume and brightness keys so Nook can replace the system HUD.
/// Needs Accessibility permission; `start()` returns false until it's granted.
final class MediaKeyTap {
    enum Key { case volumeUp, volumeDown, mute, brightnessUp, brightnessDown }

    /// Called for every volume/brightness key press/release. Return true to swallow the
    /// event (hides Apple's HUD), false to let macOS handle it as usual.
    var handler: ((_ key: Key, _ isDown: Bool, _ modifiers: NSEvent.ModifierFlags) -> Bool)?

    fileprivate var machPort: CFMachPort?

    var isRunning: Bool { machPort != nil }

    func start() -> Bool {
        guard machPort == nil else { return true }
        // NX_SYSDEFINED carries media keys; some MacBooks send brightness as
        // plain key events (key codes 144/145) instead.
        let mask = CGEventMask(1 << 14)
            | CGEventMask(1 << CGEventType.keyDown.rawValue)
            | CGEventMask(1 << CGEventType.keyUp.rawValue)
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: mediaKeyCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        machPort = port
        keyLog.notice("key tap started")
        return true
    }
}

private func mediaKeyCallback(
    proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    let pass = Unmanaged.passUnretained(event)
    guard let refcon else { return pass }
    let tap = Unmanaged<MediaKeyTap>.fromOpaque(refcon).takeUnretainedValue()

    // macOS disables slow taps; turn it straight back on.
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let port = tap.machPort { CGEvent.tapEnable(tap: port, enable: true) }
        return pass
    }

    // Only the two brightness key codes are looked at; all other typing passes untouched.
    if type == .keyDown || type == .keyUp {
        let code = event.getIntegerValueField(.keyboardEventKeycode)
        guard code == 144 || code == 145 else { return pass }
        let key: MediaKeyTap.Key = code == 144 ? .brightnessUp : .brightnessDown
        let swallow = tap.handler?(key, type == .keyDown, NSEvent(cgEvent: event)?.modifierFlags ?? []) ?? false
        return swallow ? nil : pass
    }

    guard type.rawValue == 14,
          let nsEvent = NSEvent(cgEvent: event),
          nsEvent.subtype.rawValue == 8  // NX_SUBTYPE_AUX_CONTROL_BUTTONS
    else { return pass }

    let keyCode = (nsEvent.data1 & 0xFFFF_0000) >> 16
    let keyState = (nsEvent.data1 & 0xFF00) >> 8
    let key: MediaKeyTap.Key
    switch keyCode {
    case 0: key = .volumeUp    // NX_KEYTYPE_SOUND_UP
    case 1: key = .volumeDown  // NX_KEYTYPE_SOUND_DOWN
    case 7: key = .mute        // NX_KEYTYPE_MUTE
    case 2: key = .brightnessUp    // NX_KEYTYPE_BRIGHTNESS_UP
    case 3: key = .brightnessDown  // NX_KEYTYPE_BRIGHTNESS_DOWN
    default: return pass
    }

    let swallow = tap.handler?(key, keyState == 0xA, nsEvent.modifierFlags) ?? false
    return swallow ? nil : pass
}
