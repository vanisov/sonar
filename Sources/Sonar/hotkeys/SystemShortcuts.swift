import Carbon.HIToolbox
import SwiftUI

/// macOS's own keyboard shortcuts, so Sonar can refuse one that's taken. The system only stores shortcuts you've
/// changed (in com.apple.symbolichotkeys), so defaults are listed here and the stored ones override them.
enum SystemShortcuts {
    private struct Known {
        let id: Int?  // AppleSymbolicHotKeys ID, when the shortcut has one
        let keyCode: Int
        let modifiers: NSEvent.ModifierFlags
        let name: String
    }

    private static let mask: NSEvent.ModifierFlags = [.command, .option, .control, .shift]

    private static let defaults: [Known] = [
        Known(id: 52, keyCode: kVK_ANSI_D, modifiers: [.command, .option], name: "Turn Dock hiding on/off"),
        Known(id: 64, keyCode: kVK_Space, modifiers: [.command], name: "Show Spotlight search"),
        Known(id: 65, keyCode: kVK_Space, modifiers: [.command, .option], name: "Show Finder search window"),
        Known(id: 60, keyCode: kVK_Space, modifiers: [.control], name: "Select the previous input source"),
        Known(id: 61, keyCode: kVK_Space, modifiers: [.control, .option], name: "Select the next input source"),
        Known(id: 28, keyCode: kVK_ANSI_3, modifiers: [.command, .shift], name: "Save a screenshot"),
        Known(id: 29, keyCode: kVK_ANSI_3, modifiers: [.command, .shift, .control], name: "Copy a screenshot"),
        Known(id: 30, keyCode: kVK_ANSI_4, modifiers: [.command, .shift], name: "Save a screenshot of an area"),
        Known(id: 31, keyCode: kVK_ANSI_4, modifiers: [.command, .shift, .control], name: "Copy a screenshot of an area"),
        Known(id: 184, keyCode: kVK_ANSI_5, modifiers: [.command, .shift], name: "Screenshot and recording options"),
        Known(id: 32, keyCode: kVK_UpArrow, modifiers: [.control], name: "Mission Control"),
        Known(id: 33, keyCode: kVK_DownArrow, modifiers: [.control], name: "Application windows"),
        Known(id: 79, keyCode: kVK_LeftArrow, modifiers: [.control], name: "Move left a space"),
        Known(id: 81, keyCode: kVK_RightArrow, modifiers: [.control], name: "Move right a space"),
        Known(id: nil, keyCode: kVK_ANSI_Q, modifiers: [.command, .control], name: "Lock Screen"),
        Known(id: nil, keyCode: kVK_Escape, modifiers: [.command, .option], name: "Force Quit Applications"),
        Known(id: nil, keyCode: kVK_Space, modifiers: [.command, .control], name: "Emoji & Symbols"),
        Known(id: nil, keyCode: kVK_Tab, modifiers: [.command], name: "Switch apps"),
        Known(id: nil, keyCode: kVK_ANSI_Grave, modifiers: [.command], name: "Switch windows"),
    ]

    /// The name of the macOS shortcut already using this key combination, if any.
    static func conflict(_ shortcut: Shortcut) -> String? {
        var modifiers: NSEvent.ModifierFlags = []
        if shortcut.modifiers & UInt32(cmdKey) != 0 { modifiers.insert(.command) }
        if shortcut.modifiers & UInt32(optionKey) != 0 { modifiers.insert(.option) }
        if shortcut.modifiers & UInt32(controlKey) != 0 { modifiers.insert(.control) }
        if shortcut.modifiers & UInt32(shiftKey) != 0 { modifiers.insert(.shift) }
        let keyCode = Int(shortcut.keyCode)

        let stored = UserDefaults(suiteName: "com.apple.symbolichotkeys")?.dictionary(forKey: "AppleSymbolicHotKeys") ?? [:]
        var overridden = Set<Int>()
        for (key, value) in stored {
            guard let id = Int(key), let entry = value as? [String: Any] else { continue }
            overridden.insert(id)
            guard (entry["enabled"] as? NSNumber)?.boolValue == true,
                let params = (entry["value"] as? [String: Any])?["parameters"] as? [NSNumber], params.count == 3,
                params[1].intValue == keyCode,
                NSEvent.ModifierFlags(rawValue: params[2].uintValue).intersection(mask) == modifiers
            else { continue }
            return defaults.first { $0.id == id }?.name ?? "a macOS keyboard shortcut"
        }
        return defaults.first { known in
            known.keyCode == keyCode && known.modifiers == modifiers && !(known.id.map(overridden.contains) ?? false)
        }?.name
    }
}
