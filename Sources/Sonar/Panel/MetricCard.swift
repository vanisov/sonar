import SwiftUI

struct MetricCard<Visual: View>: View {
    let title: String, symbol: String, tint: Color
    var badge: String?
    let value: String, unit: String, footer: String
    @ViewBuilder var visual: Visual

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: symbol).foregroundStyle(tint)
                Text(title).foregroundStyle(.secondary)
                Spacer(minLength: 4)
                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .medium)).monospacedDigit()
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.primary.opacity(0.07), in: Capsule())
                }
            }
            .font(.system(size: 12, weight: .semibold))

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 26, weight: .semibold, design: .rounded)).monospacedDigit()
                Text(unit).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
            }
            .lineLimit(1)

            visual.frame(maxWidth: .infinity, minHeight: 30, maxHeight: 30, alignment: .leading)

            Text(footer).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
        }
        .modifier(CardBackground())
    }
}
