import Darwin

func sysctlValue<T>(_ name: String, _ initial: T) -> T {
    var value = initial
    var size = MemoryLayout<T>.size
    _ = withUnsafeMutableBytes(of: &value) { sysctlbyname(name, $0.baseAddress, &size, nil, 0) }
    return value
}

func sysctlString(_ name: String) -> String {
    var size = 0
    guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return "" }
    var buf = [CChar](repeating: 0, count: size)
    guard sysctlbyname(name, &buf, &size, nil, 0) == 0 else { return "" }
    return String(cString: buf)
}
