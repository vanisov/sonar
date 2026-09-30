#!/usr/bin/env swift  // Renders the app icon and builds Icon/Sonar.icns.
// Run: ./Icon/make-icon.swift   (needs Xcode's toolchain: DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer)
import AppKit
import SwiftUI

let teal = Color(red: 0.08, green: 0.72, blue: 0.65)
let ink = Color(red: 0.07, green: 0.08, blue: 0.09)

/// Baseline with one rounded peak, vertically centered as a whole.
struct Pulse: Shape {
    var width: CGFloat = 520, height: CGFloat = 260, half: CGFloat = 105
    func path(in r: CGRect) -> Path {
        let y = r.midY + height / 2, x = r.midX, x0 = x - width / 2
        var p = Path()
        p.move(to: CGPoint(x: x0, y: y))
        p.addLine(to: CGPoint(x: x - half, y: y))
        p.addCurve(
            to: CGPoint(x: x, y: y - height), control1: CGPoint(x: x - half * 0.45, y: y),
            control2: CGPoint(x: x - half * 0.42, y: y - height))
        p.addCurve(
            to: CGPoint(x: x + half, y: y), control1: CGPoint(x: x + half * 0.42, y: y - height),
            control2: CGPoint(x: x + half * 0.45, y: y))
        p.addLine(to: CGPoint(x: x0 + width, y: y))
        return p
    }
}

/// Apple's macOS icon grid: 1024 canvas, 824 rounded-rect body, soft drop shadow.
struct Icon: View {
    var body: some View {
        ZStack {
            ink
            Pulse().stroke(teal, style: StrokeStyle(lineWidth: 48, lineCap: .round, lineJoin: .round))
        }
        .frame(width: 824, height: 824)
        .clipShape(RoundedRectangle(cornerRadius: 185, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 16, y: 10)
        .frame(width: 1024, height: 1024)
    }
}

let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("Sonar.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

MainActor.assumeIsolated {
    for size in [16, 32, 128, 256, 512] {
        for scale in [1, 2] {
            let renderer = ImageRenderer(
                content: Icon().scaleEffect(CGFloat(size) / 1024).frame(width: CGFloat(size), height: CGFloat(size)))
            renderer.scale = CGFloat(scale)
            let png = NSBitmapImageRep(data: renderer.nsImage!.tiffRepresentation!)!.representation(using: .png, properties: [:])!
            let name = scale == 1 ? "icon_\(size)x\(size).png" : "icon_\(size)x\(size)@2x.png"
            try! png.write(to: iconset.appendingPathComponent(name))
        }
    }
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", dir.appendingPathComponent("Sonar.icns").path]
try! iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "Wrote Icon/Sonar.icns" : "iconutil failed")
