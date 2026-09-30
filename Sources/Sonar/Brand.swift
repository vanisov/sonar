import AppKit
import SwiftUI

/// Sonar's palette. The per-metric chart colors stay semantic; `signal` is the one brand accent.
extension Color {
    static let ink = Color(red: 0.082, green: 0.090, blue: 0.110)  // #15171C
    static let steel = Color(red: 0.541, green: 0.576, blue: 0.639)  // #8A93A3
    static let signal = Color(red: 1.0, green: 0.357, blue: 0.180)  // #FF5B2E
}

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

/// Icon + wordmark lockup for the dashboard sidebar.
struct BrandLockup: View {
    var body: some View {
        HStack(spacing: 8) {
            AppMark(size: 22)
            Wordmark().fill(.primary).frame(width: 13 * Wordmark.aspectRatio, height: 13)
        }
        .accessibilityElement()
        .accessibilityLabel("Sonar")
    }
}

enum MenuBarLogo {
    /// The Levels mark as a 16 pt template image, shown when no stats are enabled.
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 16, height: 16), flipped: true) { _ in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: NSRect(x: 2, y: 7.5, width: 2.6, height: 6), xRadius: 1.3, yRadius: 1.3).fill()
            NSBezierPath(roundedRect: NSRect(x: 6.7, y: 3.5, width: 2.6, height: 10), xRadius: 1.3, yRadius: 1.3).fill()
            NSColor.black.withAlphaComponent(0.5).setFill()
            NSBezierPath(roundedRect: NSRect(x: 11.4, y: 9.5, width: 2.6, height: 4), xRadius: 1.3, yRadius: 1.3).fill()
            NSColor.black.setFill()
            NSBezierPath(ovalIn: NSRect(x: 11.2, y: 4, width: 3, height: 3)).fill()
            return true
        }
        image.isTemplate = true
        return image
    }()
}

/// After Sonar's last window closes, hand focus back to the previous app. Otherwise macOS keeps treating Sonar as the
/// active app and its services keep waking it up (~1 wake-up a second, measured with perf.sh).
@MainActor func resignActiveIfNoWindows(closing: NSWindow?) {
    let open = NSApp.windows.contains { $0 !== closing && $0.isVisible && !$0.className.contains("StatusBar") }
    if !open { NSApp.hide(nil) }
}
