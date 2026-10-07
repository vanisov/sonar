import SwiftUI

/// Which menu bar stats show, in what order, and how.
@MainActor enum MenuBarConfig {
    static var order: [MenuBarItem] {
        let saved = Prefs.string(Prefs.menuBarOrder, default: "").split(separator: ",").compactMap { MenuBarItem(rawValue: String($0)) }
        return saved + MenuBarItem.allCases.filter { !saved.contains($0) }
    }

    static var enabled: Set<MenuBarItem> {
        Set(
            Prefs.string(Prefs.menuBarItems, default: MenuBarItem.defaults).split(separator: ",")
                .compactMap { MenuBarItem(rawValue: String($0)) })
    }

    static var styles: [MenuBarItem: MenuBarItem.Style] {
        var result: [MenuBarItem: MenuBarItem.Style] = [:]
        for pair in Prefs.string(Prefs.menuBarStyles, default: "").split(separator: ",") {
            let kv = pair.split(separator: "=")
            if kv.count == 2, let item = MenuBarItem(rawValue: String(kv[0])), let style = MenuBarItem.Style(rawValue: String(kv[1])) {
                result[item] = style
            }
        }
        return result
    }

    static func style(_ item: MenuBarItem) -> MenuBarItem.Style { styles[item] ?? .iconAndValue }

    /// Enabled stats in order, each with its style applied.
    static func parts(_ part: (MenuBarItem) -> MenuBarItem.Part?) -> [MenuBarItem.Part] {
        let on = enabled
        let styles = styles
        return order.filter { on.contains($0) }.compactMap { item in
            guard var p = part(item) else { return nil }
            let style = styles[item] ?? .iconAndValue
            if style != .value { p.symbol = item.symbol }
            if style == .icon { p.value = nil }
            if item == .network, style == .value, let v = p.value { p.value = "↓" + v }
            return p
        }
    }

    static func previewImage() -> NSImage {
        let parts = parts { $0.example }
        return parts.isEmpty ? MenuBarLogo.image : render(parts, highlight: false)
    }

    /// Draws the label with AppKit text drawing. Menu bar labels drop SF Symbols embedded in Text, and SwiftUI's
    /// ImageRenderer spun up ~115 MB of GPU memory on every redraw. A template image unless something is highlighted,
    /// in which case dynamic colors keep it right in light and dark menu bars.
    static func render(_ parts: [MenuBarItem.Part], highlight: Bool) -> NSImage {
        let colored = highlight && parts.contains { $0.level > 0 }
        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        let text = NSMutableAttributedString()
        for (i, part) in parts.enumerated() {
            let color: NSColor =
                !colored ? .black : part.level == 2 ? .systemRed : part.level == 1 ? .systemOrange : .labelColor
            if i > 0 { text.append(NSAttributedString(string: "  ")) }
            if let name = part.symbol {
                let attachment = NSTextAttachment()
                var config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
                if colored { config = config.applying(.init(paletteColors: [color])) }
                attachment.image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config)
                text.append(NSAttributedString(attachment: attachment))
                if part.value != nil { text.append(NSAttributedString(string: " ")) }
            }
            if let value = part.value {
                text.append(NSAttributedString(string: value, attributes: [.foregroundColor: color]))
            }
        }
        text.addAttribute(.font, value: font, range: NSRange(location: 0, length: text.length))
        let size = text.size()
        let image = NSImage(size: NSSize(width: ceil(size.width), height: ceil(size.height)), flipped: false) { rect in
            text.draw(in: rect)
            return true
        }
        image.isTemplate = !colored
        return image
    }
}
