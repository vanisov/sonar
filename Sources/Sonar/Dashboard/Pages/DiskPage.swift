import SwiftUI

struct DiskPage: View {
    let monitor: Monitor
    @Bindable private var nav = DashboardNavigation.shared

    var body: some View {
        let m = monitor
        let used = m.diskTotal - m.diskFree
        // The tabs scroll with the page, so the toolbar looks and behaves like every other page's.
        page {
            HStack {
                Picker("Show", selection: $nav.diskCleanUp) {
                    Text("Usage").tag(false)
                    Text("Clean Up").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
                Spacer()
            }
            if nav.diskCleanUp {
                CleanUpCard()
            } else {
                usage(m, used: used)
            }
        }
    }

    private func diskStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(value).font(.system(size: 17, weight: .semibold, design: .rounded)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private func usage(_ m: Monitor, used: Int64) -> some View {
        let storage = StorageBreakdown.shared
        let segments = storage.segments(used: used)
        DashCard(title: "Macintosh HD", symbol: "internaldrive", tint: .orange, trailing: "startup disk") {
            HStack(alignment: .top, spacing: 28) {
                BigValue(value: Fmt.storage(m.diskFree), caption: "available")
                Spacer()
                diskStat("Used", Fmt.storage(used))
                diskStat("Capacity", Fmt.storage(m.diskTotal))
            }
            if segments.isEmpty {
                UsageBar(fraction: m.diskTotal > 0 ? Double(used) / Double(m.diskTotal) : 0, color: .orange)
            } else {
                // Like System Settings → General → Storage, drawn like the Memory page's breakdown.
                GeometryReader { g in
                    HStack(spacing: 2) {
                        ForEach(segments, id: \.0) { c, size in
                            Rectangle().fill(c.color).frame(width: max(0, g.size.width * Double(size) / Double(max(m.diskTotal, 1)) - 2))
                                .help("\(c.title): \(Fmt.storage(size))")
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(width: g.size.width, alignment: .leading)
                    .background(.primary.opacity(0.07))
                    .clipShape(Capsule())
                }
                .frame(height: 14)
            }
            LazyVGrid(columns: two, spacing: 0) {
                ForEach(segments, id: \.0) { c, size in keyValue(c.title, Fmt.storage(size), dot: c.color) }
            }
            HStack(spacing: 6) {
                if storage.calculating {
                    ProgressView().controlSize(.mini)
                    Text(segments.isEmpty ? "Calculating what's using space…" : "Recalculating…")
                } else if let updated = storage.updated {
                    Text("Calculated \(updated.formatted(.relative(presentation: .named)))")
                    Button("Recalculate") { storage.recalculate() }.buttonStyle(.link)
                }
            }
            .font(.caption).foregroundStyle(.secondary)
        }
        .onAppear { storage.refreshIfStale() }
        let system = storage.systemBreakdown(used: used)
        if !segments.isEmpty, !system.isEmpty {
            let total = Double(max(storage.systemDataSize(used: used), 1))
            DashCard(
                title: "System Data", symbol: "gearshape.2", tint: .secondary,
                trailing: Fmt.storage(storage.systemDataSize(used: used))
            ) {
                VStack(spacing: 0) {
                    ForEach(system, id: \.0) { part, size in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(part?.title ?? "Snapshots and other")
                                Spacer()
                                Text(Fmt.storage(size)).monospacedDigit()
                            }
                            Text(
                                part?.detail
                                    ?? "Local snapshots (including staged macOS updates), Recovery, and folders Sonar can't read"
                            )
                            .font(.caption).foregroundStyle(.secondary)
                            UsageBar(fraction: Double(size) / total, color: StorageCategory.systemData.color)
                        }
                        .padding(.vertical, 8)
                        if part != system.last?.0 { Divider() }
                    }
                }
            }
        }
        DashCard(title: "Activity", symbol: "arrow.up.arrow.down", tint: .orange, trailing: "all disks") {
            HStack(spacing: 24) {
                BigValue(value: Fmt.rate(m.diskRead), caption: "Read", dot: .orange)
                BigValue(value: Fmt.rate(m.diskWrite), caption: "Write", dot: .blue)
            }
            HistoryChart(
                times: m.times,
                series: [
                    ChartSeries(name: "Read", values: m.diskReadHistory, color: .orange),
                    ChartSeries(name: "Write", values: m.diskWriteHistory, color: .blue),
                ],
                height: 210, axis: { Fmt.rate($0) })
        }
    }
}
