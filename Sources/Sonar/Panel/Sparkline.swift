import SwiftUI

/// Filled sparkline drawn as a plain path; much cheaper to redraw than a Swift Charts chart.
struct Sparkline: View {
    let values: Ring<Float>, tint: Color
    var maxValue: Float? = 100
    var window = 60  // samples shown: 2 min

    var body: some View {
        let shown = Array(values.suffix(window))
        let top = maxValue ?? max(shown.max() ?? 1, 1)
        ZStack {
            SparklineShape(values: shown, window: window, top: top, closed: true)
                .fill(LinearGradient(colors: [tint.opacity(0.3), tint.opacity(0)], startPoint: .top, endPoint: .bottom))
            SparklineShape(values: shown, window: window, top: top, closed: false)
                .stroke(tint, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
    }
}

private struct SparklineShape: Shape {
    let values: [Float], window: Int, top: Float, closed: Bool

    func path(in rect: CGRect) -> Path {
        guard values.count > 1 else { return Path() }
        let r = rect.insetBy(dx: 0, dy: 1)  // keep the stroke inside at 0% and 100%
        let step = r.width / CGFloat(window - 1)
        let x0 = r.minX + CGFloat(window - values.count) * step  // right-aligned: fresh history grows in from the right
        let points = values.enumerated().map { i, v in
            CGPoint(x: x0 + CGFloat(i) * step, y: r.maxY - CGFloat(min(max(v / top, 0), 1)) * r.height)
        }
        var path = Path()
        path.move(to: points[0])
        // Curve through midpoints for a smooth line without overshoot.
        for i in 1..<points.count {
            let mid = CGPoint(x: (points[i - 1].x + points[i].x) / 2, y: (points[i - 1].y + points[i].y) / 2)
            path.addQuadCurve(to: mid, control: points[i - 1])
        }
        path.addLine(to: points[points.count - 1])
        if closed {
            path.addLine(to: CGPoint(x: points[points.count - 1].x, y: rect.maxY))
            path.addLine(to: CGPoint(x: points[0].x, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}
