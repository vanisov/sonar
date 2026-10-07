import SwiftUI

/// The apps using the most memory, with their CPU share.
struct AppsCard: View {
    let apps: [AppUsage]

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label("Using the most", systemImage: "chart.bar.fill").labelStyle(TintedIcon(tint: .indigo))
                Spacer()
                Text("Memory").frame(width: 66, alignment: .trailing)
                Text("CPU").frame(width: 44, alignment: .trailing).help("CPU is a share of the whole Mac")
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.secondary)

            ForEach(apps) { app in
                HStack(spacing: 8) {
                    if let icon = app.icon { Image(nsImage: icon).resizable().frame(width: 18, height: 18) }
                    Text(app.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                    Spacer()
                    Text(Fmt.memory(app.memory)).frame(width: 66, alignment: .trailing).foregroundStyle(.secondary)
                    Text(app.cpu.formatted(.number.precision(.fractionLength(1))) + "%").frame(width: 44, alignment: .trailing)
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: 12))
                .monospacedDigit()
            }
        }
        .modifier(CardBackground())
    }
}
