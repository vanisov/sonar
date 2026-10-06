import SwiftUI

/// The Levels mark on its tile, drawn natively for small in-app use (sidebar, About).
/// Same geometry as Icon/make-icon.swift: a 236-unit tile.
struct AppMark: View {
    var size: CGFloat

    var body: some View {
        Canvas { context, canvas in
            let u = canvas.width / 236
            let tile = Path(roundedRect: CGRect(origin: .zero, size: canvas), cornerRadius: 54 * u, style: .continuous)
            context.fill(
                tile,
                with: .linearGradient(
                    Gradient(colors: [.white, Color(red: 0.902, green: 0.925, blue: 0.957)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: canvas.height)))
            context.stroke(tile, with: .color(.black.opacity(0.08)), lineWidth: max(0.5, u))
            func bar(_ x: CGFloat, _ y: CGFloat, _ h: CGFloat) -> Path {
                Path(roundedRect: CGRect(x: x * u, y: y * u, width: 30 * u, height: h * u), cornerRadius: 15 * u, style: .continuous)
            }
            context.fill(bar(52, 106, 78), with: .color(.ink))
            context.fill(bar(103, 62, 122), with: .color(.ink))
            context.fill(bar(154, 128, 56), with: .color(.ink.opacity(0.35)))
            context.fill(Path(ellipseIn: CGRect(x: 153 * u, y: 72 * u, width: 32 * u, height: 32 * u)), with: .color(.signal))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
