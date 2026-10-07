import SwiftUI

/// Details for the selected processes (the toolbar's Info button, or double-click).
struct ProcessInfoView: View {
    let rows: [ProcessRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if rows.count == 1, let row = rows.first {
                HStack(spacing: 10) {
                    Group {
                        if let icon = row.icon {
                            Image(nsImage: icon).resizable()
                        } else {
                            Image(systemName: "gearshape.fill").font(.system(size: 20)).foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 32, height: 32)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(row.name).font(.headline).lineLimit(1)
                        Text(
                            verbatim: row.isApp
                                ? "Application · \(row.processCount) processes · PID \(row.id)" : "Background process · PID \(row.id)"
                        )
                        .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 6) {
                    GridRow {
                        detail("CPU", row.cpu.map { Fmt.percent($0, decimals: 1) } ?? "—")
                        detail("Memory", row.memory.map { Fmt.memory($0) } ?? "—")
                    }
                    GridRow {
                        detail("Threads", row.threads.map(String.init) ?? "—")
                        detail("User", row.user)
                    }
                }
                if let path = row.executableURL?.path {
                    Text(path).font(.caption.monospaced()).foregroundStyle(.secondary).lineLimit(2).textSelection(.enabled)
                }
                if let lock = row.locked {
                    Label(
                        lock == .otherUser
                            ? "Owned by \(row.user). Sonar doesn't end other users' or system processes."
                            : "Part of your login session. Ending it would log you out, so Sonar won't.",
                        systemImage: "lock.fill"
                    )
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("\(rows.count) processes").font(.headline)
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 6) {
                    GridRow {
                        detail("CPU", Fmt.percent(rows.compactMap(\.cpu).reduce(0, +), decimals: 1))
                        detail("Memory", Fmt.memory(rows.compactMap(\.memory).reduce(0, +)))
                    }
                }
                Text(rows.prefix(8).map(\.name).joined(separator: ", ") + (rows.count > 8 ? "…" : ""))
                    .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(width: 290)
    }

    private func detail(_ key: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(key).font(.caption).foregroundStyle(.secondary)
            Text(value).monospacedDigit().lineLimit(1)
        }
    }
}
