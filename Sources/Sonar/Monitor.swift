import AppKit
import Darwin
import IOKit

struct AppUsage: Identifiable {
    let id: pid_t
    let name: String
    let icon: NSImage?
    let memory: UInt64
    let cpu: Double
}

struct Sensor: Identifiable {
    let id: String // SMC key, e.g. "Tp01"
    let group: String
    var value: Double
    var history: [Double] = []

    static let groupOrder = ["CPU", "GPU", "SSD", "Battery", "Wi-Fi", "Ambient", "Other"]

    /// Best guess from the key prefix; Apple doesn't document these.
    static func group(for key: String) -> String {
        switch key.prefix(2) {
        case "Tp", "Te": "CPU"
        case "Tg": "GPU"
        case "TH": "SSD"
        case "TB": "Battery"
        case "TW": "Wi-Fi"
        case "TA": "Ambient"
        default: "Other"
        }
    }
}

@MainActor @Observable
final class Monitor {
    static let historyLength = 1800 // 1 h at 2 s
    static let interval: Duration = .seconds(2)

    // Every history array grows in lockstep with `times`.
    var times: [Date] = []
    var cpu = 0.0
    var cpuHistory: [Double] = []
    var gpu = 0.0
    var gpuHistory: [Double] = []
    var memoryUsed: UInt64 = 0
    var memoryHistory: [Double] = []
    var pressure = "Normal"
    var diskTotal: Int64 = 0
    var diskFree: Int64 = 0
    var down = 0.0
    var up = 0.0
    var downHistory: [Double] = []
    var upHistory: [Double] = []
    var sensors: [Sensor] = []
    var cpuTemp: Double?
    var cpuTempHistory: [Double] = []
    var gpuTemp: Double?
    var gpuTempHistory: [Double] = []
    var fanRPMs: [Double] = []
    var fansAuto = true
    var apps: [AppUsage] = [] // sorted by memory
    var uptime: TimeInterval = 0

    let chip = sysctlString("machdep.cpu.brand_string").replacingOccurrences(of: "Apple ", with: "")
    let memoryTotal = ProcessInfo.processInfo.physicalMemory
    let cores = ProcessInfo.processInfo.activeProcessorCount
    let osVersion: String = {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(v.majorVersion).\(v.minorVersion)"
    }()

    var memoryPercent: Double { Double(memoryUsed) / Double(memoryTotal) * 100 }

    private let smc = SMC()
    private var lastTicks: (busy: UInt64, total: UInt64)?
    private var lastNet: (down: UInt64, up: UInt64)?
    private var lastProcCPU: [pid_t: UInt64] = [:]
    private var icons: [pid_t: NSImage] = [:] // NSRunningApplication.icon hits the disk every call
    private var lastSample = Date()
    private let tickToNanos: Double = {
        var tb = mach_timebase_info_data_t()
        mach_timebase_info(&tb)
        return Double(tb.numer) / Double(tb.denom)
    }()

    init() {
        // Sensor keys differ per chip, so discover every temperature key that reads a sane value.
        sensors = (smc?.allKeys() ?? [])
            .filter { $0.hasPrefix("T") }
            .compactMap { key in
                guard let v = smc?.read(key), Self.plausibleTemp(v) else { return nil }
                return Sensor(id: key, group: Sensor.group(for: key), value: v)
            }
            .sorted { (Sensor.groupOrder.firstIndex(of: $0.group)!, $0.id) < (Sensor.groupOrder.firstIndex(of: $1.group)!, $1.id) }
        Task { while true { sample(); try? await Task.sleep(for: Self.interval) } }
    }

    /// Unused sensor slots report whole-number placeholders (e.g. exactly 40.0 on M4); real readings have fractions.
    private static func plausibleTemp(_ v: Double) -> Bool { (15...125).contains(v) && v != v.rounded() }

    private func sample() {
        let now = Date()
        let elapsed = max(now.timeIntervalSince(lastSample), 0.1)
        lastSample = now
        push(now, to: &times)

        let ticks = cpuTicks()
        if let last = lastTicks, ticks.total > last.total {
            cpu = Double(ticks.busy - last.busy) / Double(ticks.total - last.total) * 100
        }
        lastTicks = ticks
        push(cpu, to: &cpuHistory)

        gpu = gpuUtilization() ?? 0
        push(gpu, to: &gpuHistory)

        memoryUsed = usedMemory()
        push(memoryPercent, to: &memoryHistory)
        pressure = switch sysctlValue("kern.memorystatus_vm_pressure_level", Int32(1)) {
        case 4: "Critical"
        case 2: "Warning"
        default: "Normal"
        }

        // Free space asks the purgeable-space service, which is slow; disk barely moves anyway.
        if times.count % 15 == 1, let v = try? URL(fileURLWithPath: "/").resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]) {
            diskTotal = Int64(v.volumeTotalCapacity ?? 0)
            diskFree = v.volumeAvailableCapacityForImportantUsage ?? 0
        }

        let net = networkBytes()
        if let last = lastNet {
            down = Double(net.down &- last.down) / elapsed
            up = Double(net.up &- last.up) / elapsed
        }
        lastNet = net
        push(down, to: &downHistory)
        push(up, to: &upHistory)

        // CPU/GPU feed the popover and menu bar every tick; the ~200 other sensors only show in the dashboard.
        let everyone = times.count % 5 == 1
        sensors = sensors.map { sensor in
            guard everyone || sensor.group == "CPU" || sensor.group == "GPU" else { return sensor }
            var s = sensor
            if let v = smc?.read(s.id), Self.plausibleTemp(v) { s.value = v }
            push(s.value, to: &s.history)
            return s
        }
        cpuTemp = average(of: "CPU")
        gpuTemp = average(of: "GPU")
        push(cpuTemp ?? 0, to: &cpuTempHistory)
        push(gpuTemp ?? 0, to: &gpuTempHistory)

        let fanCount = Int(smc?.read("FNum") ?? 0)
        fanRPMs = (0..<fanCount).compactMap { smc?.read("F\($0)Ac") }
        fansAuto = (0..<fanCount).allSatisfy { (smc?.read("F\($0)Md") ?? 0) == 0 }

        sampleApps(elapsed: elapsed)
        uptime = now.timeIntervalSince1970 - Double(sysctlValue("kern.boottime", timeval()).tv_sec)
    }

    private func push<T>(_ value: T, to history: inout [T]) {
        history.append(value)
        if history.count > Self.historyLength { history.removeFirst() }
    }

    private func average(of group: String) -> Double? {
        let temps = sensors.filter { $0.group == group }.map(\.value)
        return temps.isEmpty ? nil : temps.reduce(0, +) / Double(temps.count)
    }

    private func cpuTicks() -> (busy: UInt64, total: UInt64) {
        var count: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &count, &info, &infoCount) == KERN_SUCCESS,
              let info else { return (0, 0) }
        defer { vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.stride)) }
        var busy: UInt64 = 0, total: UInt64 = 0
        for core in 0..<Int(count) {
            let base = core * Int(CPU_STATE_MAX)
            func ticks(_ state: Int32) -> UInt64 { UInt64(UInt32(bitPattern: info[base + Int(state)])) }
            let used = ticks(CPU_STATE_USER) + ticks(CPU_STATE_SYSTEM) + ticks(CPU_STATE_NICE)
            busy += used
            total += used + ticks(CPU_STATE_IDLE)
        }
        return (busy, total)
    }

    /// Activity Monitor's "Memory Used": app memory + wired + compressed.
    private func usedMemory() -> UInt64 {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count) }
        }
        guard kr == KERN_SUCCESS else { return 0 }
        let pages = UInt64(stats.internal_page_count) - min(UInt64(stats.purgeable_count), UInt64(stats.internal_page_count))
            + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)
        return pages * UInt64(vm_kernel_page_size)
    }

    private func gpuUtilization() -> Double? {
        var iter: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("IOAccelerator"), &iter) == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iter) }
        var result: Double?
        while case let entry = IOIteratorNext(iter), entry != 0 {
            defer { IOObjectRelease(entry) }
            let stats = IORegistryEntryCreateCFProperty(entry, "PerformanceStatistics" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? [String: Any]
            if let util = stats?["Device Utilization %"] as? Int { result = max(result ?? 0, Double(util)) }
        }
        return result
    }

    /// 64-bit byte counters for physical interfaces (en*), so VPN tunnels aren't double-counted.
    private func networkBytes() -> (down: UInt64, up: UInt64) {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var len = 0
        guard sysctl(&mib, 6, nil, &len, nil, 0) == 0 else { return (0, 0) }
        var buf = [UInt8](repeating: 0, count: len)
        guard sysctl(&mib, 6, &buf, &len, nil, 0) == 0 else { return (0, 0) }
        var down: UInt64 = 0, up: UInt64 = 0, offset = 0
        var name = [CChar](repeating: 0, count: Int(IF_NAMESIZE))
        buf.withUnsafeBytes { raw in
            while offset + MemoryLayout<if_msghdr>.size <= len {
                let hdr = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr.self)
                if Int32(hdr.ifm_type) == RTM_IFINFO2 {
                    let h2 = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                    if if_indextoname(UInt32(h2.ifm_index), &name) != nil, String(cString: name).hasPrefix("en") {
                        down += h2.ifm_data.ifi_ibytes
                        up += h2.ifm_data.ifi_obytes
                    }
                }
                offset += max(Int(hdr.ifm_msglen), 1)
            }
        }
        return (down, up)
    }

    /// Sums every process into the app responsible for it (Safari + its web content processes, etc.).
    private func sampleApps(elapsed: Double) {
        let running = Dictionary(NSWorkspace.shared.runningApplications
            .filter { $0.bundleURL?.pathExtension == "app" }
            .map { ($0.processIdentifier, $0) }, uniquingKeysWith: { a, _ in a })

        var pids = [pid_t](repeating: 0, count: 4096) // ponytail: fixed cap, grow if someone runs >4k processes
        let n = Int(proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size)))
        var totals: [pid_t: (memory: UInt64, cpu: UInt64)] = [:]
        var nextCPU: [pid_t: UInt64] = [:]

        for pid in pids.prefix(max(n, 0)) where pid > 0 {
            var info = rusage_info_v2()
            let ok = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V2, $0) }
            } == 0
            guard ok else { continue } // other users' / root processes
            let cpuTime = info.ri_user_time + info.ri_system_time
            nextCPU[pid] = cpuTime
            let owner = responsiblePID?(pid) ?? pid
            guard running[owner] != nil else { continue }
            totals[owner, default: (0, 0)].memory += info.ri_phys_footprint
            totals[owner, default: (0, 0)].cpu += cpuTime &- (lastProcCPU[pid] ?? cpuTime)
        }
        lastProcCPU = nextCPU
        icons = icons.filter { running[$0.key] != nil }

        apps = totals.sorted { $0.value.memory > $1.value.memory }.compactMap { pid, total in
            guard let app = running[pid] else { return nil }
            let seconds = Double(total.cpu) * tickToNanos / 1e9
            if icons[pid] == nil { icons[pid] = app.icon }
            return AppUsage(id: pid, name: app.localizedName ?? "Unknown", icon: icons[pid],
                            memory: total.memory, cpu: seconds / (elapsed * Double(cores)) * 100)
        }
    }
}

/// Private libSystem call Activity Monitor-style tools use to group helper processes under their app.
private let responsiblePID: ((pid_t) -> pid_t)? = {
    guard let sym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "responsibility_get_pid_responsible_for_pid") else { return nil } // -2 = RTLD_DEFAULT
    let fn = unsafeBitCast(sym, to: (@convention(c) (pid_t) -> pid_t).self)
    return { fn($0) }
}()

func sysctlValue<T>(_ name: String, _ initial: T) -> T {
    var value = initial
    var size = MemoryLayout<T>.size
    _ = withUnsafeMutableBytes(of: &value) { sysctlbyname(name, $0.baseAddress, &size, nil, 0) }
    return value
}

func sysctlString(_ name: String) -> String {
    var size = 0
    sysctlbyname(name, nil, &size, nil, 0)
    var buf = [CChar](repeating: 0, count: size)
    sysctlbyname(name, &buf, &size, nil, 0)
    return String(cString: buf)
}
