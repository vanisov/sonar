#!/usr/bin/env swift
// Builds docs/hero.png: the real panel (rendered by the app) open under Sonar's menu bar item on a Mac desktop.
//
//   .build/debug/Sonar --snapshot /tmp/panel.png 125 --clear      # 2 min of history, no background
//   swift docs/make-hero.swift /tmp/panel.png docs/hero.png 16% 53°
//
// The wallpaper, menu bar and glass are drawn here; every pixel of the panel itself comes from the app.

import AppKit
import CoreImage

let args = CommandLine.arguments
guard args.count >= 5, let panel = NSImage(contentsOfFile: args[1]) else {
    print("usage: make-hero.swift panel.png out.png <cpu%> <temp>")
    exit(1)
}
let (out, cpu, temp) = (args[2], args[3], args[4])

let scale: CGFloat = 2
let size = CGSize(width: 980, height: 860)  // points
let menuHeight: CGFloat = 30
let panelSize = CGSize(width: panel.size.width / scale, height: panel.size.height / scale)

func rgb(_ hex: Int, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// The wallpaper: soft color fields like the prototype.
func wallpaper(_ ctx: CGContext) {
    ctx.setFillColor(rgb(0x29285A).cgColor)
    ctx.fill(CGRect(origin: .zero, size: size))
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let fields: [(CGPoint, CGFloat, Int)] = [
        (CGPoint(x: 0.18, y: 0.70), 0.62, 0x3B5BA9), (CGPoint(x: 0.82, y: 0.82), 0.55, 0xC2548A),
        (CGPoint(x: 0.70, y: 0.08), 0.70, 0xE58A3A), (CGPoint(x: 0.25, y: 0.04), 0.58, 0x2E8C8A),
    ]
    for (center, radius, hex) in fields {
        let c = CGPoint(x: center.x * size.width, y: center.y * size.height)
        let gradient = CGGradient(colorsSpace: space, colors: [rgb(hex).cgColor, rgb(hex, 0).cgColor] as CFArray, locations: [0, 1])!
        ctx.drawRadialGradient(gradient, startCenter: c, startRadius: 0, endCenter: c, endRadius: radius * size.width, options: [])
    }
}

func symbol(_ name: String, _ pointSize: CGFloat, weight: NSFont.Weight = .medium) -> NSImage {
    let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight).applying(.init(paletteColors: [.white]))
    return NSImage(systemSymbolName: name, accessibilityDescription: nil)!.withSymbolConfiguration(config)!
}

func text(_ s: String, _ size: CGFloat, _ weight: NSFont.Weight, at p: CGPoint, color: NSColor = .white) -> CGFloat {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight).withMonospacedDigits(), .foregroundColor: color,
    ]
    let str = NSAttributedString(string: s, attributes: attrs)
    str.draw(at: p)
    return str.size().width
}

extension NSFont {
    func withMonospacedDigits() -> NSFont {
        let d = fontDescriptor.addingAttributes([
            .featureSettings: [[NSFontDescriptor.FeatureKey.typeIdentifier: kNumberSpacingType, .selectorIdentifier: kMonospacedNumbersSelector]]
        ])
        return NSFont(descriptor: d, size: pointSize) ?? self
    }
}

// 1. Wallpaper, kept as an image so the glass can blur it.
let base = NSImage(size: size)
base.lockFocus()
wallpaper(NSGraphicsContext.current!.cgContext)
base.unlockFocus()

let canvas = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale), bitsPerSample: 8,
    samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
canvas.size = size
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: canvas)
let ctx = NSGraphicsContext.current!.cgContext
base.draw(in: CGRect(origin: .zero, size: size))

// 2. Menu bar.
let bar = CGRect(x: 0, y: size.height - menuHeight, width: size.width, height: menuHeight)
rgb(0x14141E, 0.32).setFill()
bar.fill()
let baseline = bar.minY + 7
symbol("apple.logo", 14).draw(at: CGPoint(x: 16, y: baseline - 1), from: .zero, operation: .sourceOver, fraction: 1)
var x: CGFloat = 46
x += text("Finder", 13, .bold, at: CGPoint(x: x, y: baseline)) + 20
for item in ["File", "Edit", "View", "Go", "Window", "Help"] { x += text(item, 13, .regular, at: CGPoint(x: x, y: baseline)) + 20 }

// right side, laid out from the clock leftwards
var right = size.width - 14
let clock = "Mon Oct 5  9:41 AM"
let clockWidth = NSAttributedString(string: clock, attributes: [.font: NSFont.systemFont(ofSize: 13)]).size().width
right -= clockWidth
_ = text(clock, 13, .regular, at: CGPoint(x: right, y: baseline))
right -= 34
symbol("battery.75percent", 15).draw(at: CGPoint(x: right, y: baseline), from: .zero, operation: .sourceOver, fraction: 1)
right -= 30
symbol("wifi", 14).draw(at: CGPoint(x: right, y: baseline), from: .zero, operation: .sourceOver, fraction: 1)

// Sonar's item, highlighted because its panel is open: CPU icon and %, thermometer and temperature.
let itemWidth: CGFloat = 108
right -= itemWidth + 14
let item = CGRect(x: right, y: bar.minY + 4, width: itemWidth, height: menuHeight - 8)
rgb(0xFFFFFF, 0.22).setFill()
NSBezierPath(roundedRect: item, xRadius: 5, yRadius: 5).fill()
var ix = item.minX + 8
symbol("cpu", 13).draw(at: CGPoint(x: ix, y: baseline), from: .zero, operation: .sourceOver, fraction: 1)
ix += 19
ix += text(cpu, 12.5, .semibold, at: CGPoint(x: ix, y: baseline + 0.5)) + 8
symbol("thermometer.medium", 13).draw(at: CGPoint(x: ix, y: baseline), from: .zero, operation: .sourceOver, fraction: 1)
ix += 12
_ = text(temp, 12.5, .semibold, at: CGPoint(x: ix, y: baseline + 0.5))

// 3. The panel on glass, centered under the item.
let panelX = min(max(item.midX - panelSize.width / 2, 8), size.width - panelSize.width - 8)
let frame = CGRect(x: panelX, y: bar.minY - 8 - panelSize.height, width: panelSize.width, height: panelSize.height)
let shape = NSBezierPath(roundedRect: frame, xRadius: 18, yRadius: 18)

NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
shadow.shadowBlurRadius = 40
shadow.shadowOffset = NSSize(width: 0, height: -20)
shadow.set()
rgb(0x1E2028).setFill()
shape.fill()
NSGraphicsContext.restoreGraphicsState()

// glass: the wallpaper behind the panel, blurred and tinted dark
let wallCG = base.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let blurred = CIImage(cgImage: wallCG).clampedToExtent().applyingGaussianBlur(sigma: 40 * scale).cropped(to: CIImage(cgImage: wallCG).extent)
let blurCG = CIContext().createCGImage(blurred, from: blurred.extent)!
NSGraphicsContext.saveGraphicsState()
shape.addClip()
ctx.draw(blurCG, in: CGRect(origin: .zero, size: size))
rgb(0x1E2028, 0.64).setFill()
frame.fill()
panel.draw(in: frame)
NSGraphicsContext.restoreGraphicsState()
rgb(0xFFFFFF, 0.16).setStroke()
shape.lineWidth = 1
shape.stroke()

NSGraphicsContext.restoreGraphicsState()
try! canvas.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out) (\(canvas.pixelsWide)×\(canvas.pixelsHigh))")
