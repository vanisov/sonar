import SystemConfiguration

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
