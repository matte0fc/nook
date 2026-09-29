import SwiftUI

/// State shared between the notch window and the view it hosts.
final class HUDModel: ObservableObject {
    enum Kind { case volume, brightness }

    @Published var isExpanded = false
    @Published var kind: Kind = .volume
    @Published var level: Float = 0
    @Published var isMuted = false
    @Published var notchSize = CGSize(width: 185, height: 32)
    @Published var hasNotch = true

    private var collapseWork: DispatchWorkItem?

    func show(_ kind: Kind, level: Float, muted: Bool = false) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            self.kind = kind
            self.level = level
            self.isMuted = muted
        }
        if !isExpanded {
            withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) { isExpanded = true }
        }

        collapseWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            withAnimation(.spring(response: 0.3, dampingFraction: 1)) { self?.isExpanded = false }
        }
        collapseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: work)
    }
}
