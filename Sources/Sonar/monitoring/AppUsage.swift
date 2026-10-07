import AppKit

struct AppUsage: Identifiable {
    let id: pid_t
    let name: String
    let icon: NSImage?
    let memory: UInt64
    let cpu: Double
}
