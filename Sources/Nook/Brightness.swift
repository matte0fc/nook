import CoreGraphics
import Foundation

/// Built-in display brightness via Apple's DisplayServices framework (the same
/// API the brightness keys use). It's private, so it's loaded at runtime.
enum Brightness {
    private typealias GetFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetFn = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private static let framework = dlopen(
        "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW)
    private static let getBrightness: GetFn? = framework
        .flatMap { dlsym($0, "DisplayServicesGetBrightness") }
        .map { unsafeBitCast($0, to: GetFn.self) }
    private static let setBrightness: SetFn? = framework
        .flatMap { dlsym($0, "DisplayServicesSetBrightness") }
        .map { unsafeBitCast($0, to: SetFn.self) }

    /// The MacBook's own screen, or nil when the lid is closed.
    static var builtInDisplay: CGDirectDisplayID? {
        var count: UInt32 = 0
        CGGetOnlineDisplayList(0, nil, &count)
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetOnlineDisplayList(count, &displays, &count)
        return displays.first { CGDisplayIsBuiltin($0) != 0 && CGDisplayIsAsleep($0) == 0 }
    }

    static var isAvailable: Bool {
        getBrightness != nil && setBrightness != nil && builtInDisplay != nil
    }

    static var level: Float {
        get {
            guard let display = builtInDisplay, let getBrightness else { return 0 }
            var value: Float = 0
            _ = getBrightness(display, &value)
            return value
        }
        set {
            guard let display = builtInDisplay, let setBrightness else { return }
            _ = setBrightness(display, min(max(newValue, 0), 1))
        }
    }
}
