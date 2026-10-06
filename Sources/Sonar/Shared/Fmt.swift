import SwiftUI

/// Number formatting that follows the Units settings.
enum Fmt {
    /// Storage sizes: GB like Finder (1000) or GiB (1024).
    static func storage<T: BinaryInteger>(_ bytes: T) -> String {
        let v = Int64(bytes)
        return Prefs.bool(Prefs.storageBinary, default: false)
            ? v.formatted(.byteCount(style: .binary, spellsOutZero: false))
            : v.formatted(.byteCount(style: .file, spellsOutZero: false))
    }

    /// Memory sizes, like Activity Monitor.
    static func memory<T: BinaryInteger>(_ bytes: T) -> String {
        Int64(bytes).formatted(.byteCount(style: .memory, spellsOutZero: false))
    }

    /// Throughput in bytes/s or bits/s.
    static func rate(_ bytesPerSecond: Double) -> String {
        let v = max(bytesPerSecond, 0)
        if Prefs.bool(Prefs.networkBits, default: false) {
            let bits = v * 8
            let units: [(Double, String)] = [(1e9, "Gb/s"), (1e6, "Mb/s"), (1e3, "kb/s")]
            for (scale, unit) in units where bits >= scale {
                return "\((bits / scale).formatted(.number.precision(.significantDigits(1...3)))) \(unit)"
            }
            return "\(Int(bits)) b/s"
        }
        return Int64(v).formatted(.byteCount(style: .file, spellsOutZero: false)) + "/s"
    }

    static func percent(_ v: Double, decimals: Int = 0) -> String {
        "\(v.formatted(.number.precision(.fractionLength(decimals))))%"
    }

    /// "13d 6h" / "3h 12m"
    static func uptime(_ t: TimeInterval) -> String {
        let m = Int(t) / 60, h = m / 60, d = h / 24
        return d > 0 ? "\(d)d \(h % 24)h" : "\(h)h \(m % 60)m"
    }

    /// "293.11 GB" -> ("293.11", "GB")
    static func split(_ s: String) -> (String, String) {
        let parts = s.split(whereSeparator: \.isWhitespace)
        return (String(parts.first ?? ""), parts.dropFirst().joined(separator: " "))
    }
}
