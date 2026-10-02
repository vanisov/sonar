import SwiftUI

struct PanelView: View {
    let monitor: Monitor
    @State private var visible = false
    @State private var size = CGSize(width: 380, height: 740)
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            // MenuBarExtra keeps a closed popover alive offscreen. Rendering nothing while closed stops it
            // observing Monitor; otherwise every sample re-rendered it and animations never settled (~20% CPU).
            if !visible {
                Color.clear.frame(width: size.width, height: size.height)
            } else {
                PanelContent(
                    monitor: monitor,
                    openDashboard: { section in
                        dismiss()  // a new key window doesn't close the popover on its own
                        DashboardWindow.show(section)
                    },
                    openSettings: {
                        dismiss()
                        SettingsWindow.open()
                    }
                )
                .background(
                    GeometryReader { g in
                        Color.clear.onAppear { size = g.size }.onChange(of: g.size) { _, new in size = new }
                    })
            }
        }
        .onAppear {
            visible = true
            monitor.viewAppeared()
        }
        .onDisappear {
            visible = false
            monitor.viewDisappeared()
        }
    }
}
