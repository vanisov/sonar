enum MenuBarItem: String, CaseIterable, Identifiable {
    case cpu, cpuTemp, gpuTemp, memory, network, fan

    static let storageKey = "menuBarItems"
    static let defaults = "cpu,cpuTemp"

    enum Style: String, CaseIterable {
        case iconAndValue = "both", value, icon

        var title: String {
            switch self {
            case .iconAndValue: "Icon and value"
            case .value: "Value only"
            case .icon: "Icon only"
            }
        }
    }

    /// One stat as drawn: an optional SF Symbol, an optional value, and how urgent it is (0 normal, 1 warm, 2 hot).
    struct Part {
        var symbol: String?
        var value: String?
        var level = 0
    }

    var id: Self { self }

    var title: String {
        switch self {
        case .cpu: "CPU usage"
        case .cpuTemp: "CPU temperature"
        case .gpuTemp: "GPU temperature"
        case .memory: "Memory"
        case .network: "Network download"
        case .fan: "Fan speed"
        }
    }

    var symbol: String {
        switch self {
        case .cpu: "cpu"
        case .cpuTemp: "thermometer.medium"
        case .gpuTemp: "square.stack.3d.up"
        case .memory: "memorychip"
        case .network: "arrow.down"
        case .fan: "fan"
        }
    }

    @MainActor func part(_ m: Monitor, decimals: Int) -> Part? {
        func number(_ v: Double) -> String { v.formatted(.number.precision(.fractionLength(decimals))) }
        func level(_ v: Double, warm: Double, hot: Double) -> Int { v >= hot ? 2 : v >= warm ? 1 : 0 }
        func degrees(_ c: Double) -> Part { Part(value: number(TemperatureUnit.convert(c)) + "°", level: level(c, warm: 90, hot: 100)) }
        return switch self {
        case .cpu: Part(value: number(m.cpu) + "%", level: level(m.cpu, warm: 80, hot: 95))
        case .cpuTemp: m.cpuTemp.map(degrees)
        case .gpuTemp: m.gpuTemp.map(degrees)
        case .memory: Part(value: number(m.memoryPercent) + "%", level: m.pressure == "Critical" ? 2 : m.pressure == "Warning" ? 1 : 0)
        case .network: Part(value: Fmt.rate(m.down))
        case .fan: m.fanRPMs.max().map { Part(value: String(Int($0))) }
        }
    }

    /// Fixed example values for the Settings preview, so Settings never has to observe live data.
    var example: Part {
        switch self {
        case .cpu: Part(value: "34%")
        case .cpuTemp: Part(value: "\(Int(TemperatureUnit.convert(45).rounded()))°")
        case .gpuTemp: Part(value: "\(Int(TemperatureUnit.convert(40).rounded()))°")
        case .memory: Part(value: "67%")
        case .network: Part(value: Fmt.rate(4200))
        case .fan: Part(value: "1350")
        }
    }
}
