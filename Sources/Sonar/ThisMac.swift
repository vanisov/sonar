import AppKit
import IOKit
import IOKit.ps
import SwiftUI
import SystemConfiguration

/// Hardware and software facts that don't change while Sonar runs, read once.
struct MacInfo {
    static let shared = MacInfo()

    let productName: String  // "MacBook Pro (16-inch, Nov 2024)"
    let modelIdentifier: String  // "Mac16,7"
    let chip: String
    let performanceCores: Int
    let efficiencyCores: Int
    let gpuCores: Int?
    let memory: UInt64
    let osVersion: String  // "27.0"
    let osBuild: String
    let kernel: String
    let bootDate: Date

    private init() {
        productName = Self.registryString("IODeviceTree:/product", "product-name") ?? "Mac"
        modelIdentifier = sysctlString("hw.model")
        chip = sysctlString("machdep.cpu.brand_string")
        performanceCores = Int(sysctlValue("hw.perflevel0.logicalcpu", Int32(0)))
        efficiencyCores = Int(sysctlValue("hw.perflevel1.logicalcpu", Int32(0)))
        gpuCores = Self.gpuCoreCount()
        memory = ProcessInfo.processInfo.physicalMemory
        let v = ProcessInfo.processInfo.operatingSystemVersion
        osVersion = v.patchVersion > 0 ? "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)" : "\(v.majorVersion).\(v.minorVersion)"
        osBuild = sysctlString("kern.osversion")
        kernel = "Darwin " + sysctlString("kern.osrelease")
        bootDate = Date(timeIntervalSince1970: Double(sysctlValue("kern.boottime", timeval()).tv_sec))
    }

    private static func registryString(_ path: String, _ key: String) -> String? {
        let entry = IORegistryEntryFromPath(kIOMainPortDefault, path)
        guard entry != 0 else { return nil }
        defer { IOObjectRelease(entry) }
        guard let data = IORegistryEntryCreateCFProperty(entry, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Data
        else { return nil }
        return String(decoding: data.prefix { $0 != 0 }, as: UTF8.self)
    }

    private static func gpuCoreCount() -> Int? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AGXAccelerator"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        return IORegistryEntryCreateCFProperty(service, "gpu-core-count" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int
    }
}

/// Battery health and charge from the SMC's battery service; nil on desktops.
struct BatteryInfo {
    let charge: Int
    let maxCapacity: Int?
    let cycles: Int?
    let charging: Bool
    let onPower: Bool
    let fullyCharged: Bool
    let adapterWatts: Int?

    static func read() -> BatteryInfo? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
            let dict = props?.takeRetainedValue() as? [String: Any]
        else { return nil }
        let data = dict["BatteryData"] as? [String: Any]
        let design = data?["DesignCapacity"] as? Int
        let nominal = data?["NominalChargeCapacity"] as? Int
        return BatteryInfo(
            charge: dict["CurrentCapacity"] as? Int ?? 0,
            maxCapacity: design.flatMap { d in nominal.map { Int((Double($0) / Double(d) * 100).rounded()) } },
            cycles: dict["CycleCount"] as? Int,
            charging: dict["IsCharging"] as? Bool ?? false,
            onPower: dict["ExternalConnected"] as? Bool ?? false,
            fullyCharged: dict["FullyCharged"] as? Bool ?? false,
            adapterWatts: (dict["AdapterDetails"] as? [String: Any])?["Watts"] as? Int)
    }

    var powerSource: String {
        guard onPower else { return "Battery" }
        let adapter = adapterWatts.map { "Power adapter · \($0) W" } ?? "Power adapter"
        return adapter + (charging ? " · Charging" : fullyCharged ? " · Charged" : " · Not charging")
    }
}

struct NetworkInterface {
    let bsd: String
    let name: String
    let address: String?

    /// Hardware interfaces with their friendly names (Wi-Fi, Ethernet…) and IPv4 address, if connected.
    static func all() -> [NetworkInterface] {
        var addresses: [String: String] = [:]
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddr) == 0, let first = ifaddr {
            defer { freeifaddrs(ifaddr) }
            for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
                let ifa = ptr.pointee
                guard let sa = ifa.ifa_addr, sa.pointee.sa_family == UInt8(AF_INET) else { continue }
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(sa, socklen_t(sa.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                    addresses[String(cString: ifa.ifa_name)] = String(cString: host)
                }
            }
        }
        let all = (SCNetworkInterfaceCopyAll() as? [SCNetworkInterface]) ?? []
        return all.compactMap { iface in
            guard let bsd = SCNetworkInterfaceGetBSDName(iface) as String?, bsd.hasPrefix("en") else { return nil }
            let name = SCNetworkInterfaceGetLocalizedDisplayName(iface) as String? ?? bsd
            return NetworkInterface(bsd: bsd, name: name, address: addresses[bsd])
        }
        .sorted { ($0.address == nil ? 1 : 0, $0.bsd) < ($1.address == nil ? 1 : 0, $1.bsd) }
    }
}

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
