struct Sensor: Identifiable {
    let id: String  // SMC key, e.g. "Tp01"
    let code: UInt32
    let group: String
    var value: Double
    var history = Ring<Float>()

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
