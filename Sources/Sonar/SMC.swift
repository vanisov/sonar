import Foundation
import IOKit

/// Mirrors the kernel's SMCKeyData_t (80 bytes). Field order and the explicit padding matter.
struct SMCKeyData {
    struct Vers { var major: UInt8 = 0, minor: UInt8 = 0, build: UInt8 = 0, reserved: UInt8 = 0, release: UInt16 = 0 }
    struct PLimit { var version: UInt16 = 0, length: UInt16 = 0, cpu: UInt32 = 0, gpu: UInt32 = 0, mem: UInt32 = 0 }
    struct KeyInfo { var dataSize: UInt32 = 0, dataType: UInt32 = 0, dataAttributes: UInt8 = 0 }
    typealias Bytes = (
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
        UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
    )

    var key: UInt32 = 0
    var vers = Vers()
    var pLimit = PLimit()
    var keyInfo = KeyInfo()
    var padding: UInt16 = 0
    var result: UInt8 = 0, status: UInt8 = 0, data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: Bytes = (
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    )
}

/// Read-only access to the System Management Controller (temperatures, fans).
final class SMC {
    private var conn: io_connect_t = 0
    private var infoCache: [UInt32: SMCKeyData.KeyInfo] = [:]

    init?() {
        precondition(MemoryLayout<SMCKeyData>.stride == 80, "SMCKeyData layout drifted")
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        guard IOServiceOpen(service, mach_task_self_, 0, &conn) == KERN_SUCCESS else { return nil }
    }

    deinit { IOServiceClose(conn) }

    func read(_ key: String) -> Double? { read(Self.fourCC(key)) }

    /// Read by four-char code; precompute codes with `SMC.fourCC` for hot paths.
    func read(_ code: UInt32) -> Double? {
        var input = SMCKeyData()
        input.key = code
        if let cached = infoCache[input.key] {
            input.keyInfo = cached
        } else {
            input.data8 = 9  // get key info
            guard let info = call(&input) else { return nil }
            input.keyInfo = info.keyInfo
            infoCache[input.key] = info.keyInfo
        }
        input.data8 = 5  // read bytes
        guard let out = call(&input) else { return nil }
        return Self.decode(out.bytes, type: Self.string(input.keyInfo.dataType), size: Int(input.keyInfo.dataSize))
    }

    /// Every key this SMC exposes. Slow-ish (thousands of calls), so call once.
    func allKeys() -> [String] {
        guard let count = read("#KEY") else { return [] }
        return (0..<Int(count)).compactMap { i in
            var input = SMCKeyData()
            input.data8 = 8  // key at index
            input.data32 = UInt32(i)
            return call(&input).map { Self.string($0.key) }
        }
    }

    private func call(_ input: inout SMCKeyData) -> SMCKeyData? {
        var output = SMCKeyData()
        var size = MemoryLayout<SMCKeyData>.stride
        let kr = IOConnectCallStructMethod(conn, 2, &input, MemoryLayout<SMCKeyData>.stride, &output, &size)
        return kr == KERN_SUCCESS && output.result == 0 ? output : nil
    }

    private static func decode(_ bytes: SMCKeyData.Bytes, type: String, size: Int) -> Double? {
        let b = withUnsafeBytes(of: bytes) { Array($0.prefix(size)) }
        let be16 = b.count >= 2 ? UInt16(b[0]) << 8 | UInt16(b[1]) : 0
        switch (type, b.count) {
        case ("flt ", 4): return Double(b.withUnsafeBytes { $0.loadUnaligned(as: Float32.self) })
        case ("ui8 ", 1): return Double(b[0])
        case ("ui16", 2): return Double(be16)
        case ("ui32", 4): return Double(b.reduce(UInt32(0)) { $0 << 8 | UInt32($1) })
        case ("fpe2", 2): return Double(be16) / 4  // Intel fans
        case ("sp78", 2): return Double(Int16(bitPattern: be16)) / 256  // Intel temps
        default: return nil
        }
    }

    static func fourCC(_ s: String) -> UInt32 { s.utf8.reduce(0) { $0 << 8 | UInt32($1) } }

    private static func string(_ v: UInt32) -> String {
        String(bytes: [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: v >> $0) }, encoding: .ascii) ?? ""
    }
}
