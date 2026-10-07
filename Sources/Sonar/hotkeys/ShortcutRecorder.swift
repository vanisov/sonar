import Carbon.HIToolbox
import SwiftUI

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
