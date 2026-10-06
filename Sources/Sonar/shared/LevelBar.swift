import SwiftUI

/// A level bar whose fill glides to each new value on the window server (Core Animation). Smooth, but Sonar does
/// no per-frame work, unlike SwiftUI animations, whose timer kept waking Sonar after the dashboard closed.
struct LevelBar: NSViewRepresentable {
    var fraction: Double
    var color: Color
    var vertical = false
    var cornerRadius: CGFloat = 4

    func makeNSView(context: Context) -> LevelBarView { LevelBarView() }

    func updateNSView(_ view: LevelBarView, context: Context) {
        view.fraction = min(max(fraction, 0), 1)
        view.color = NSColor(color)
        view.vertical = vertical
        view.cornerRadius = cornerRadius
        view.needsLayout = true
    }
}

final class LevelBarView: NSView {
    var fraction = 0.0
    var color = NSColor.controlAccentColor
    var vertical = false
    var cornerRadius: CGFloat = 4
    private let track = CALayer()
    private let fill = CALayer()

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.addSublayer(track)
        layer?.addSublayer(fill)
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        let filled =
            vertical
            ? CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height * fraction)
            : CGRect(x: 0, y: 0, width: bounds.width * fraction, height: bounds.height)
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.7)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeInEaseOut))
        effectiveAppearance.performAsCurrentDrawingAppearance {
            track.backgroundColor = NSColor.labelColor.withAlphaComponent(0.08).cgColor
            fill.backgroundColor = color.cgColor
        }
        track.frame = bounds
        track.cornerRadius = cornerRadius
        fill.cornerRadius = cornerRadius
        fill.frame = filled
        CATransaction.commit()
    }
}
