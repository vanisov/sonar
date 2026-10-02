import SwiftUI

struct TopApps: View {
    let title: String
    let apps: [AppUsage]

    var body: some View {
        DashCard(title: title, symbol: "square.grid.2x2", tint: .signal) {
            VStack(spacing: 0) {
                ForEach(apps) { app in
                    HStack(spacing: 8) {
                        if let icon = app.icon { Image(nsImage: icon).resizable().frame(width: 18, height: 18) }
                        Text(app.name).lineLimit(1)
                        Spacer()
                        Text(Fmt.memory(app.memory)).foregroundStyle(.secondary).frame(width: 80, alignment: .trailing)
                        Text(Fmt.percent(app.cpu, decimals: 1)).foregroundStyle(.secondary).frame(width: 56, alignment: .trailing)
                    }
                    .monospacedDigit()
                    .padding(.vertical, 5)
                    Divider().opacity(app.id == apps.last?.id ? 0 : 1)
                }
            }
        }
    }
}
