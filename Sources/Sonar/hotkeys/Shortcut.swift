import Carbon.HIToolbox
import SwiftUI

/// A global keyboard shortcut, stored as "keyCode:carbonModifiers:display".
struct Shortcut: Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
    let display: String

    var storage: String { "\(keyCode):\(modifiers):\(display)" }

    init?(storage: String) {
        let parts = storage.split(separator: ":", maxSplits: 2).map(String.init)
        guard parts.count == 3, let code = UInt32(parts[0]), let mods = UInt32(parts[1]) else { return nil }
        (keyCode, modifiers, display) = (code, mods, parts[2])
    }

    /// Needs ⌘, ⌥ or ⌃ so it can't hijack plain typing.
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !flags.intersection([.command, .option, .control]).isEmpty else { return nil }
        var mods: UInt32 = 0
        var symbols = ""
        if flags.contains(.control) { mods |= UInt32(controlKey); symbols += "⌃" }
        if flags.contains(.option) { mods |= UInt32(optionKey); symbols += "⌥" }
        if flags.contains(.shift) { mods |= UInt32(shiftKey); symbols += "⇧" }
        if flags.contains(.command) { mods |= UInt32(cmdKey); symbols += "⌘" }
        let key: String =
            switch Int(event.keyCode) {
            case kVK_Space: "Space"
            case kVK_Return: "↩"
            case kVK_LeftArrow: "←"
            case kVK_RightArrow: "→"
            case kVK_UpArrow: "↑"
            case kVK_DownArrow: "↓"
            default: event.charactersIgnoringModifiers?.uppercased() ?? "?"
            }
        (keyCode, modifiers, display) = (UInt32(event.keyCode), mods, symbols + key)
    }
}
