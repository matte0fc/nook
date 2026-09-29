import AppKit
import ServiceManagement
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let model = HUDModel()
    private let volume = VolumeController()
    private let keys = MediaKeyTap()
    private var panel: NotchPanel!
    private var statusItem: NSStatusItem!
    private var permissionTimer: Timer?
    private var brightnessTimer: Timer?
    private var lastBrightness: Float = -1

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = NotchPanel()
        panel.contentView = NSHostingView(rootView: NotchView(model: model))
        layoutPanel()
        panel.orderFrontRegardless()

        NotificationCenter.default.addObserver(
            self, selector: #selector(layoutPanel),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)

        // Volume changed from anywhere else (Control Center, AirPods, other apps).
        volume.onChange = { [weak self] level, muted in
            self?.model.show(.volume, level: level, muted: muted)
        }
        keys.handler = { [weak self] key, isDown, modifiers in
            self?.handle(key, isDown: isDown, modifiers: modifiers) ?? false
        }

        setUpStatusItem()
        startKeyTap()
        watchBrightness()
    }

    /// Shows the HUD when brightness changes from anywhere (keys, Control Center slider).
    /// There's no public change notification, so poll; it's a single cheap call.
    private func watchBrightness() {
        brightnessTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, Brightness.isAvailable else { return }
                let level = Brightness.level
                // Ignore the tiny drifts auto-brightness makes.
                if self.lastBrightness >= 0 && abs(level - self.lastBrightness) > 0.008 {
                    self.model.show(.brightness, level: level)
                }
                self.lastBrightness = level
            }
        }
    }

    // MARK: - Volume and brightness keys

    private func handle(_ key: MediaKeyTap.Key, isDown: Bool, modifiers: NSEvent.ModifierFlags) -> Bool {
        // Shift+Option gives quarter steps, like macOS.
        let steps: Float = modifiers.contains([.shift, .option]) ? 64 : 16

        switch key {
        case .brightnessUp, .brightnessDown:
            // Lid closed / external display only: leave it to macOS.
            guard Brightness.isAvailable else { return false }
            guard isDown else { return true }
            let level = step(Brightness.level, steps: steps, up: key == .brightnessUp)
            Brightness.level = level
            lastBrightness = level
            model.show(.brightness, level: level)
            return true

        case .volumeUp, .volumeDown, .mute:
            // Outputs macOS can't control (e.g. HDMI monitors) keep the system behaviour.
            guard volume.canSetVolume else { return false }
            guard isDown else { return true }
            var level = volume.volume
            var muted = volume.isMuted
            if key == .mute {
                muted.toggle()
                volume.isMuted = muted
            } else {
                level = step(level, steps: steps, up: key == .volumeUp)
                volume.volume = level
                if key == .volumeUp && muted {
                    muted = false
                    volume.isMuted = false
                }
            }
            model.show(.volume, level: level, muted: muted)
            return true
        }
    }

    private func step(_ level: Float, steps: Float, up: Bool) -> Float {
        min(max(((level * steps).rounded() + (up ? 1 : -1)) / steps, 0), 1)
    }

    private func startKeyTap() {
        if !AXIsProcessTrusted() {
            let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
            AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)
        }
        if keys.start() { return }

        // Wait for the user to grant Accessibility access, then hook the keys.
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else { return timer.invalidate() }
                if AXIsProcessTrusted() && self.keys.start() { timer.invalidate() }
            }
        }
    }

    // MARK: - Window placement

    @objc private func layoutPanel() {
        let screen = NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
            ?? NSScreen.main ?? NSScreen.screens[0]
        let frame = screen.frame
        let hasNotch = screen.safeAreaInsets.top > 0

        var notchWidth: CGFloat = 185
        var centerX = frame.midX
        if hasNotch, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            notchWidth = frame.width - left.width - right.width
            centerX = frame.minX + left.width + notchWidth / 2
        }
        let notchHeight = hasNotch ? screen.safeAreaInsets.top : NSStatusBar.system.thickness

        model.notchSize = CGSize(width: notchWidth, height: notchHeight)
        model.hasNotch = hasNotch

        // Big enough for the expanded HUD plus its shadow; the rest is transparent
        // and click-through.
        let width = notchWidth + 60
        let height = notchHeight + NotchView.drop + 30
        panel.setFrame(
            NSRect(x: centerX - width / 2, y: frame.maxY - height, width: width, height: height),
            display: true)
    }

    // MARK: - Menu bar

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "rectangle.topthird.inset.filled", accessibilityDescription: "Nook")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if !keys.isRunning {
            menu.addItem(withTitle: "Grant Accessibility Access…",
                         action: #selector(openAccessibilitySettings), keyEquivalent: "").target = self
            menu.addItem(.separator())
        }

        menu.addItem(withTitle: "Preview Volume HUD", action: #selector(previewHUD), keyEquivalent: "")
            .target = self

        let login = menu.addItem(withTitle: "Launch at Login", action: #selector(toggleLaunchAtLogin),
                                 keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Nook", action: #selector(NSApplication.terminate(_:)),
                     keyEquivalent: "q")
    }

    @objc private func previewHUD() {
        model.show(.volume, level: volume.volume, muted: volume.isMuted)
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}

/// A borderless, click-through panel that floats above the menu bar.
final class NotchPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // Allow the window to sit over the menu bar / notch area.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}
