import SwiftUI

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
