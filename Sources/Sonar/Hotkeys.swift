import AppKit
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

/// Registers system-wide shortcuts with Carbon's hot key API, which needs no Accessibility permission.
@MainActor enum Hotkeys {
    private static var refs: [UInt32: EventHotKeyRef] = [:]
    private static var actions: [UInt32: () -> Void] = [:]
    private static var handlerInstalled = false

    static func reload() {
        register(id: 1, Prefs.dashboardShortcut) { DashboardWindow.show(nil) }
    }

    private static func register(id: UInt32, _ key: String, action: @escaping () -> Void) {
        if let ref = refs.removeValue(forKey: id) { UnregisterEventHotKey(ref) }
        guard let shortcut = Shortcut(storage: Prefs.string(key, default: "")) else { return }
        installHandler()
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x534F_4E52), id: id)  // 'SONR'
        if RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref) == noErr,
            let ref
        {
            refs[id] = ref
            actions[id] = action
        }
    }

    private static func installHandler() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ in
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                    MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
                MainActor.assumeIsolated { Hotkeys.actions[hotKeyID.id]?() }  // Carbon delivers on the main thread
                return noErr
            }, 1, &spec, nil, nil)
    }
}

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

/// Click to record, then press the shortcut. Esc cancels, Delete clears.
struct ShortcutRecorder: View {
    let key: String
    @AppStorage private var stored: String
    @State private var recording = false
    @State private var monitor: Any?
    @State private var warning: String?

    init(key: String) {
        self.key = key
        _stored = AppStorage(wrappedValue: "", key)
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            recorder
            if let warning { Text(warning).font(.caption).foregroundStyle(.red).multilineTextAlignment(.trailing) }
        }
    }

    private var recorder: some View {
        HStack(spacing: 6) {
            Button {
                recording ? stop() : start()
            } label: {
                Text(recording ? "Type shortcut…" : Shortcut(storage: stored)?.display ?? "Record Shortcut")
                    .monospacedDigit()
                    .frame(minWidth: 110)
            }
            if !stored.isEmpty && !recording {
                Button {
                    stored = ""
                    Hotkeys.reload()
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Remove shortcut")
            }
        }
        .onDisappear(perform: stop)
    }

    private func start() {
        recording = true
        warning = nil
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch Int(event.keyCode) {
            case kVK_Escape: stop()
            case kVK_Delete, kVK_ForwardDelete:
                stored = ""
                stop()
            default:
                guard let shortcut = Shortcut(event: event) else { NSSound.beep(); return nil }
                if let taken = SystemShortcuts.conflict(shortcut) {
                    NSSound.beep()
                    warning = "macOS already uses \(shortcut.display) for \(taken). Try another."
                    return nil  // keep recording
                }
                warning = nil
                stored = shortcut.storage
                stop()
            }
            Hotkeys.reload()
            return nil
        }
    }

    private func stop() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
