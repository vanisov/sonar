import SwiftUI

struct ThisMacPage: View {
    let monitor: Monitor
    @State private var battery = BatteryInfo.read()
    @State private var copied = false
    private let info = MacInfo.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 16) {
                        group("Hardware", hardware)
                        group("Displays", displays)
                    }
                    VStack(spacing: 16) {
                        group("Software", software)
                        if let battery { group("Battery", batteryRows(battery)) }
                    }
                }
                storage
            }
            .padding(20)
        }
        .onAppear { battery = BatteryInfo.read() }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Image(systemName: info.productName.contains("Book") ? "laptopcomputer" : "desktopcomputer")
                .font(.system(size: 38, weight: .light)).foregroundStyle(.secondary).frame(width: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(info.productName).font(.title2.weight(.semibold))
                Text("\(info.chip) · \(Fmt.memory(info.memory)) memory · macOS \(info.osVersion)").foregroundStyle(.secondary)
            }
            Spacer()
            Button(copied ? "Copied" : "Copy Specs") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(specsText, forType: .string)
                copied = true
            }
        }
        .padding(16)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var hardware: [(String, String)] {
        var rows = [("Model identifier", info.modelIdentifier), ("Chip", info.chip)]
        rows.append(
            (
                "CPU",
                "\(info.performanceCores + info.efficiencyCores) cores · \(info.performanceCores) performance, \(info.efficiencyCores) efficiency"
            ))
        if let gpu = info.gpuCores { rows.append(("GPU", "\(gpu) cores")) }
        rows.append(("Memory", "\(Fmt.memory(info.memory)) unified"))
        return rows
    }

    private var displays: [(String, String)] {
        NSScreen.screens.map { screen in
            let px = screen.frame.size.applying(CGAffineTransform(scaleX: screen.backingScaleFactor, y: screen.backingScaleFactor))
            let hz = screen.maximumFramesPerSecond
            return (screen.localizedName, "\(Int(px.width)) × \(Int(px.height))\(hz > 0 ? " · \(hz) Hz" : "")")
        }
    }

    private var software: [(String, String)] {
        [
            ("macOS", "Version \(info.osVersion) (\(info.osBuild))"),
            ("Kernel", info.kernel),
            ("Uptime", Fmt.uptime(monitor.uptime)),
            ("Last boot", info.bootDate.formatted(date: .abbreviated, time: .shortened)),
            ("Thermal state", ThermalState.current.title),
            ("Low Power Mode", ProcessInfo.processInfo.isLowPowerModeEnabled ? "On" : "Off"),
        ]
    }

    private func batteryRows(_ b: BatteryInfo) -> [(String, String)] {
        var rows = [("Charge", "\(b.charge)%")]
        if let max = b.maxCapacity { rows.append(("Maximum capacity", "\(max)%")) }
        if let cycles = b.cycles { rows.append(("Cycle count", "\(cycles)")) }
        rows.append(("Power source", b.powerSource))
        return rows
    }

    private var storage: some View {
        let used = monitor.diskTotal - monitor.diskFree
        return VStack(alignment: .leading, spacing: 6) {
            Text("Storage").font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.leading, 4)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Macintosh HD")
                    Spacer()
                    Text("\(Fmt.storage(monitor.diskFree)) available of \(Fmt.storage(monitor.diskTotal))").foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                UsageBar(fraction: monitor.diskTotal > 0 ? Double(used) / Double(monitor.diskTotal) : 0, color: .orange)
            }
            .padding(14)
            .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.primary.opacity(0.07)))
        }
    }

    private func group(_ title: String, _ rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.leading, 4)
            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                    HStack(alignment: .firstTextBaseline, spacing: 16) {
                        Text(row.0)
                        Spacer(minLength: 8)
                        Text(row.1).foregroundStyle(.secondary).multilineTextAlignment(.trailing).monospacedDigit().textSelection(.enabled)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    if i < rows.count - 1 { Divider().padding(.leading, 14) }
                }
            }
            .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.primary.opacity(0.07)))
        }
        .frame(maxWidth: .infinity)
    }

    private var specsText: String {
        var lines = ["\(info.productName) (\(info.modelIdentifier))"]
        lines += (hardware + software.prefix(2) + displays).map { "\($0.0): \($0.1)" }
        if let b = battery { lines += batteryRows(b).map { "\($0.0): \($0.1)" } }
        lines.append("Storage: \(Fmt.storage(monitor.diskTotal))")
        return lines.joined(separator: "\n")
    }
}
