import SwiftUI

struct NotchView: View {
    @ObservedObject var model: HUDModel

    /// How far the HUD drops below the notch. The notch itself has no pixels,
    /// so the icon and bar live in this strip.
    static let drop: CGFloat = 22

    var body: some View {
        let notch = model.notchSize
        let open = model.isExpanded

        // Always exactly notch-wide; only the height animates, so the HUD slides
        // straight down out of the notch instead of growing from its centre.
        ZStack(alignment: .bottom) {
            Color.black
            // Pinned to the bottom edge, so it rides down with it.
            indicator
        }
        .frame(width: notch.width, height: open ? notch.height + Self.drop : notch.height)
        .clipShape(NotchShape(topRadius: 0, bottomRadius: open ? 14 : 8))
        // Hidden while idle so no edge can peek out around the hardware notch.
        // Appear instantly; disappear only once it has slid back up.
        .animation(open ? .linear(duration: 0.01) : .easeOut(duration: 0.1).delay(0.3)) {
            $0.opacity(open ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var indicator: some View {
        HStack(spacing: 9) {
            Image(systemName: iconName, variableValue: Double(model.level))
                .font(.system(size: 11, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 16)

            LevelBar(value: model.isMuted ? 0 : model.level, dimmed: model.isMuted)
                .frame(height: 4)
        }
        .padding(.horizontal, 16)
        .frame(height: Self.drop)
        // Slightly dimmed white: less backlight bloom, so the black around it
        // stays closer to the hardware notch.
        .foregroundStyle(.white.opacity(0.85))
    }

    private var iconName: String {
        switch model.kind {
        case .brightness:
            return model.level < 0.5 ? "sun.min.fill" : "sun.max.fill"
        case .volume:
            return model.isMuted || model.level <= 0.001 ? "speaker.slash.fill" : "speaker.wave.3.fill"
        }
    }
}

private struct LevelBar: View {
    var value: Float
    var dimmed: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.14))
                Capsule()
                    .fill(.white.opacity(dimmed ? 0.3 : 0.85))
                    .frame(width: geo.size.width * CGFloat(value))
                    .opacity(value > 0 ? 1 : 0)
            }
        }
    }
}

/// The notch silhouette: concave "flares" where it meets the top edge of the
/// screen and rounded bottom corners, like the hardware cut-out.
struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set { topRadius = newValue.first; bottomRadius = newValue.second }
    }

    func path(in rect: CGRect) -> Path {
        let t = topRadius
        let b = min(bottomRadius, rect.height / 2, (rect.width - 2 * t) / 2)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX + t, y: rect.minY + t),
            control: CGPoint(x: rect.minX + t, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + t, y: rect.maxY - b))
        p.addQuadCurve(
            to: CGPoint(x: rect.minX + t + b, y: rect.maxY),
            control: CGPoint(x: rect.minX + t, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - t - b, y: rect.maxY))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX - t, y: rect.maxY - b),
            control: CGPoint(x: rect.maxX - t, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - t, y: rect.minY + t))
        p.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - t, y: rect.minY))
        p.closeSubpath()
        return p
    }
}
