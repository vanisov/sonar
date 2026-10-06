import SwiftUI

/// A full-width panel card: title and current value on the left, context (peak, temperature) on the right, and a
/// graph underneath. Every graph card has the same header and graph height, so they line up.
struct GraphCard<Value: View, Trailing: View, Graph: View>: View {
    let title: String
    let symbol: String
    let tint: Color
    @ViewBuilder var value: Value
    @ViewBuilder var trailing: Trailing
    @ViewBuilder var graph: Graph

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .bottom, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Label(title, systemImage: symbol).labelStyle(TintedIcon(tint: tint))
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                    value.lineLimit(1)
                }
                Spacer(minLength: 6)
                HStack(spacing: 7) { trailing }.padding(.bottom, 3)
            }
            graph.frame(height: 40)
        }
        .modifier(CardBackground())
    }
}

/// Disk and fans: a value, a short caption and a level bar. They change slowly, so no graph.
struct StatCard<Value: View>: View {
    let title: String
    let symbol: String
    let tint: Color
    @ViewBuilder var value: Value
    let caption: String
    let fraction: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(title, systemImage: symbol).labelStyle(TintedIcon(tint: tint))
                .font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
            value.lineLimit(1).padding(.top, 3)
            Text(caption).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            Spacer(minLength: 9)
            GeometryReader { g in
                ZStack(alignment: .leading) {
                    Capsule().fill(.primary.opacity(0.08))
                    Capsule().fill(tint.gradient).frame(width: g.size.width * min(max(fraction, 0), 1))
                }
            }
            .frame(height: 6)
        }
        .modifier(CardBackground())
    }
}

/// "34.2 GB of 48": the number large, then its unit and any qualifier.
struct ValueText: View {
    let value: String
    var unit = ""
    var qualifier: String?
    var size: CGFloat = 22

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(value).font(.system(size: size, weight: .semibold, design: .rounded)).monospacedDigit()
            Text(unit).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
            if let qualifier {
                Text(qualifier).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.secondary).padding(.leading, 4)
            }
        }
    }
}

/// A temperature in a capsule that turns amber when warm and orange when hot.
struct TemperaturePill: View {
    let celsius: Double?

    var body: some View {
        if let celsius {
            Text(TemperatureUnit.format(celsius))
                .font(.system(size: 11, weight: .semibold, design: .rounded)).monospacedDigit()
                .foregroundStyle(celsius >= 85 ? Color.signal : celsius >= 70 ? Color.temperature : Color.primary)
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background(.primary.opacity(0.08), in: Capsule())
        }
    }
}

/// "peak 61%" for the visible window.
struct PeakLabel: View {
    let values: Ring<Float>
    let window: Int

    var body: some View {
        let peak = values.suffix(window).max() ?? 0
        Text("peak \(Int(peak.rounded()))%").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary).monospacedDigit()
    }
}
