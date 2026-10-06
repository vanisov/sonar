#!/usr/bin/env swift

// Renders the app icon and builds Icon/Sonar.icns.
// Run: ./Icon/make-icon.swift   (needs Xcode's toolchain: DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer)
import AppKit
import SwiftUI

let ink = Color(red: 0.082, green: 0.090, blue: 0.110)  // #15171C
let signal = Color(red: 1.0, green: 0.357, blue: 0.180)  // #FF5B2E

/// The Levels mark: three readings as rounded bars, the one that needs attention in signal orange.
/// Geometry is in a 236-unit tile (same as the brand board); Sources/Sonar/Shared/Brand/AppMark.swift draws the same mark.
struct Levels: View {
    var body: some View {
        GeometryReader { g in
            let u = g.size.width / 236
            ZStack(alignment: .topLeading) {
                bar(x: 52, y: 106, h: 78, u: u).fill(ink)
                bar(x: 103, y: 62, h: 122, u: u).fill(ink)
                bar(x: 154, y: 128, h: 56, u: u).fill(ink.opacity(0.35))
                Circle().fill(signal).frame(width: 32 * u, height: 32 * u).offset(x: 153 * u, y: 72 * u)
            }
        }
    }

    private func bar(x: CGFloat, y: CGFloat, h: CGFloat, u: CGFloat) -> some Shape {
        RoundedRectangle(cornerRadius: 15 * u, style: .continuous)
            .path(in: CGRect(x: x * u, y: y * u, width: 30 * u, height: h * u))
    }
}

/// Apple's macOS icon grid: 1024 canvas, 824 rounded-rect body, soft drop shadow.
struct Icon: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.white, Color(red: 0.902, green: 0.925, blue: 0.957)], startPoint: .top, endPoint: .bottom)
            Levels()
        }
        .frame(width: 824, height: 824)
        .clipShape(RoundedRectangle(cornerRadius: 185, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 185, style: .continuous).strokeBorder(.black.opacity(0.08), lineWidth: 3))
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
