import Carbon.HIToolbox

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
