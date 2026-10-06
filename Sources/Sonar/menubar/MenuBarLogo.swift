import SwiftUI

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
