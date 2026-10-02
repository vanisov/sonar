import SwiftUI

struct TopAppsCard: View {
    let apps: [AppUsage]

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("Top apps", systemImage: "chart.bar.fill").labelStyle(TintedIcon(tint: .indigo))
                Spacer()
                Text("Memory").frame(width: 72, alignment: .trailing)
                Text("CPU").frame(width: 46, alignment: .trailing)
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)

            ForEach(apps) { app in
                HStack(spacing: 8) {
                    if let icon = app.icon { Image(nsImage: icon).resizable().frame(width: 18, height: 18) }
                    Text(app.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                    Spacer()
                    Text(Fmt.memory(app.memory)).frame(width: 72, alignment: .trailing)
                    Text(app.cpu.formatted(.number.precision(.fractionLength(1))) + "%").frame(width: 46, alignment: .trailing)
                }
                .font(.system(size: 12))
                .monospacedDigit()
            }

            Text("CPU is a share of the whole Mac").font(.system(size: 10)).foregroundStyle(.tertiary)
        }
        .modifier(CardBackground())
    }
}
