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

        // Before/after comparison: the standard macOS pop-up (illustration) vs Nook.
        for (name, useNook) in [("compare-before", false), ("compare-after", true)] {
            let model = HUDModel()
            model.level = 0.62
            model.isExpanded = true
            let renderer = ImageRenderer(content: ComparisonScene(model: model, useNook: useNook))
            renderer.scale = 2
            guard let image = renderer.cgImage,
                  let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
            else { continue }
            try? png.write(to: dir.appendingPathComponent("\(name).png"))
            print("wrote \(name).png")
        }
    }
}

/// The top of a MacBook screen, showing either the system volume pop-up
/// (a simplified illustration) or Nook.
private struct ComparisonScene: View {
    @ObservedObject var model: HUDModel
    let useNook: Bool

    var body: some View {
        let notch = model.notchSize
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [Color(red: 0.95, green: 0.58, blue: 0.40), Color(red: 0.33, green: 0.29, blue: 0.58)],
                startPoint: .topLeading, endPoint: .bottomTrailing)

            // Menu bar with placeholder items
            ZStack {
                Rectangle().fill(.white.opacity(0.22))
                HStack(spacing: 14) {
                    ForEach([34, 44, 52, 40], id: \.self) { w in
                        Capsule().fill(.white.opacity(0.55)).frame(width: CGFloat(w), height: 7)
                    }
                    Spacer()
                    ForEach([16, 16, 16, 60], id: \.self) { w in
                        Capsule().fill(.white.opacity(0.55)).frame(width: CGFloat(w), height: 7)
                    }
                }
                .padding(.horizontal, 18)
            }
            .frame(height: notch.height)

            NotchShape(topRadius: 0, bottomRadius: 9)
                .fill(.black)
                .frame(width: notch.width, height: notch.height)

            if useNook {
                NotchView(model: model)
                    .frame(height: notch.height + NotchView.drop + 30)
            } else {
                systemPopUp
                    .padding(.top, notch.height + 8)
                    .padding(.trailing, 10)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .frame(width: 760, height: 136)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var systemPopUp: some View {
        VStack(alignment: .leading, spacing: 10) {
            Capsule().fill(.white.opacity(0.75)).frame(width: 46, height: 7)
            HStack(spacing: 10) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 13, weight: .semibold))
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.3))
                    Capsule().fill(.white).frame(width: 150 * 0.62)
                }
                .frame(width: 150, height: 8)
            }
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(white: 0.35).opacity(0.55))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.white.opacity(0.35), lineWidth: 1))
                .shadow(color: .black.opacity(0.25), radius: 12, y: 4)
        )
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
