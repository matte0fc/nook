import AppKit

MainActor.assumeIsolated {
    let args = CommandLine.arguments
    if let flag = args.firstIndex(of: "--render-previews") {
        PreviewRenderer.run(outputDirectory: flag + 1 < args.count ? args[flag + 1] : "docs/images")
        exit(0)
    }

    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
