import AppKit
import SwiftUI

/// `Nook --render-previews <dir>` writes PNGs of the HUD, drawn by the real
/// `NotchView`, onto a mock menu bar. Used for the README images.
@MainActor
enum PreviewRenderer {
    static func run(outputDirectory: String) {
        let dir = URL(fileURLWithPath: outputDirectory, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let states: [(String, HUDModel.Kind, Float, Bool, Bool)] = [
            ("volume", .volume, 0.62, false, true),
            ("brightness", .brightness, 0.8, false, true),
            ("muted", .volume, 0.62, true, true),
        ]
        for (name, kind, level, muted, expanded) in states {
            let model = HUDModel()
            model.kind = kind
            model.level = level
            model.isMuted = muted
            model.isExpanded = expanded

            let renderer = ImageRenderer(content: PreviewScene(model: model))
            renderer.scale = 3
            guard let image = renderer.cgImage,
                  let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
            else { continue }
            try? png.write(to: dir.appendingPathComponent("hud-\(name).png"))
            print("wrote hud-\(name).png")
        }
    }
}

private struct PreviewScene: View {
    @ObservedObject var model: HUDModel

    var body: some View {
        let notch = model.notchSize
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.58, blue: 0.40), Color(red: 0.33, green: 0.29, blue: 0.58)],
                startPoint: .topLeading, endPoint: .bottomTrailing)

            // Menu bar
            Rectangle().fill(.white.opacity(0.22)).frame(height: notch.height)

            // The hardware notch
            NotchShape(topRadius: 0, bottomRadius: 9)
                .fill(.black)
                .frame(width: notch.width, height: notch.height)

            NotchView(model: model)
                .frame(height: notch.height + NotchView.drop + 30)
        }
        .frame(width: 440, height: 96)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
