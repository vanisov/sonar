import AppKit

extension Monitor {
    /// Every process on the Mac as table rows. App rows total the app and its helpers (same grouping as the panel);
    /// every other process also gets its own background row, so a helper or anything started from a terminal can
    /// be found and ended on its own. Other users' processes (root daemons, WindowServer…) can't be read
    /// without admin rights, so they're listed with name, PID and owner only.
    func sampleProcesses() {
        let now = Date()
        let elapsed = max(now.timeIntervalSince(lastRowsSample), 0.1)
        lastRowsSample = now
        let me = getuid()
        let running = Dictionary(
            NSWorkspace.shared.runningApplications.filter { $0.bundleURL?.pathExtension == "app" }.map { ($0.processIdentifier, $0) },
            uniquingKeysWith: { a, _ in a })

        struct Totals {
            var cpu: UInt64 = 0, memory: UInt64 = 0, threads = 0, processes = 0
        }
        var appTotals: [pid_t: Totals] = [:]
        var rows: [ProcessRow] = []
        var nextCPU: [pid_t: UInt64] = [:]
        var seen = Set<pid_t>()

        for (pid, uid, comm) in Self.allProcesses() where pid > 0 {
            seen.insert(pid)
            let name = processNames[pid] ?? Self.processName(pid, fallback: comm)
            processNames[pid] = name
            let user = userNames[uid] ?? (getpwuid(uid).map { String(cString: $0.pointee.pw_name) } ?? "\(uid)")
            userNames[uid] = user
            guard uid == me else {
                rows.append(ProcessRow(id: pid, name: name, user: user, locked: .otherUser))
                continue
            }
            var usage = rusage_info_v2()
            let readable =
                withUnsafeMutablePointer(to: &usage) {
                    $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V2, $0) }
                } == 0
            var task = proc_taskinfo()
            let threads =
                proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &task, Int32(MemoryLayout<proc_taskinfo>.size)) > 0 ? Int(task.pti_threadnum) : nil
            let cpuTime = readable ? usage.ri_user_time + usage.ri_system_time : 0
            nextCPU[pid] = cpuTime
            let delta = cpuTime &- (lastRowCPU[pid] ?? cpuTime)
            let owner = responsiblePID?(pid) ?? pid
            if running[owner] != nil {
                appTotals[owner, default: Totals()].cpu += delta
                appTotals[owner, default: Totals()].memory += readable ? usage.ri_phys_footprint : 0
                appTotals[owner, default: Totals()].threads += threads ?? 0
                appTotals[owner, default: Totals()].processes += 1
            }
            if running[pid] != nil { continue }  // the app itself is its own row below
            rows.append(
                ProcessRow(
                    id: pid, name: name, user: user, cpu: readable ? percent(delta, elapsed) : nil,
                    memory: readable ? usage.ri_phys_footprint : nil, threads: threads,
                    locked: ProcessRow.protectedNames.contains(name) ? .protected : nil))
        }
        lastRowCPU = nextCPU
        for (pid, total) in appTotals {
            guard let app = running[pid] else { continue }
            rows.append(
                ProcessRow(
                    id: pid, name: app.localizedName ?? processNames[pid] ?? "App", user: userNames[me] ?? "",
                    cpu: percent(total.cpu, elapsed),
                    memory: total.memory, threads: total.threads,
                    locked: ProcessRow.protectedNames.contains(processNames[pid] ?? "") ? .protected : nil,
                    app: app, processCount: total.processes))
        }
        processNames = processNames.filter { seen.contains($0.key) }
        processes = rows
    }

    private func percent(_ ticks: UInt64, _ elapsed: Double) -> Double {
        Double(ticks) * tickToNanos / 1e9 / (elapsed * Double(cores)) * 100
    }

    /// pid, owner and short name of every process, including other users' (sysctl works without privileges).
    private static func allProcesses() -> [(pid_t, uid_t, String)] {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size = 0
        guard sysctl(&mib, 4, nil, &size, nil, 0) == 0 else { return [] }
        let stride = MemoryLayout<kinfo_proc>.stride
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: size / stride + 32)
        size = procs.count * stride
        guard sysctl(&mib, 4, &procs, &size, nil, 0) == 0 else { return [] }
        return procs.prefix(size / stride).map { kp in
            var comm = kp.kp_proc.p_comm
            let name = withUnsafeBytes(of: &comm) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
            return (kp.kp_proc.p_pid, kp.kp_eproc.e_ucred.cr_uid, name)
        }
    }

    /// Full executable name (the short sysctl name is cut at 16 characters).
    private static func processName(_ pid: pid_t, fallback: String) -> String {
        var path = [CChar](repeating: 0, count: 4096)
        guard proc_pidpath(pid, &path, UInt32(path.count)) > 0 else { return fallback }
        return URL(fileURLWithPath: String(cString: path)).lastPathComponent
    }
}

/// Private libSystem call Activity Monitor-style tools use to group helper processes under their app.
let responsiblePID: ((pid_t) -> pid_t)? = {
    let rtldDefault = UnsafeMutableRawPointer(bitPattern: -2)
    guard let sym = dlsym(rtldDefault, "responsibility_get_pid_responsible_for_pid") else { return nil }
    let fn = unsafeBitCast(sym, to: (@convention(c) (pid_t) -> pid_t).self)
    return { fn($0) }
}()
