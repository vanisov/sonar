import SwiftUI

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
