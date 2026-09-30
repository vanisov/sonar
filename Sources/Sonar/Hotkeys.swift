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

/// Click to record, then press the shortcut. Esc cancels, Delete clears.
struct ShortcutRecorder: View {
    let key: String
    @AppStorage private var stored: String
    @State private var recording = false
    @State private var monitor: Any?

    init(key: String) {
        self.key = key
        _stored = AppStorage(wrappedValue: "", key)
    }

    var body: some View {
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
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch Int(event.keyCode) {
            case kVK_Escape: stop()
            case kVK_Delete, kVK_ForwardDelete:
                stored = ""
                stop()
            default:
                guard let shortcut = Shortcut(event: event) else { NSSound.beep(); return nil }
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
