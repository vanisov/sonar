import SwiftUI

/// A bar split into parts (where memory or disk space goes). Hovering a part, or its row in the legend, highlights
/// it and shows what it is, how much, its share, and any details (e.g. the apps behind "App memory").
struct SegmentBar: View {
    struct Segment: Identifiable {
        let id: String  // also the label
        let value: Double
        let color: Color
        var details: [String] = []
    }

    let segments: [Segment]
    let total: Double
    let format: (Double) -> String
    @Binding var highlighted: String?

    var body: some View {
        GeometryReader { g in
            let widths = segments.map { max(g.size.width * $0.value / max(total, 1) - 2, 0) }
            HStack(spacing: 2) {
                ForEach(Array(segments.enumerated()), id: \.element.id) { i, segment in
                    Rectangle()
                        .fill(segment.color.opacity(highlighted == nil || highlighted == segment.id ? 1 : 0.35))
                        .frame(width: widths[i])
                        .contentShape(Rectangle())
                        .onHover { inside in
                            if inside { highlighted = segment.id } else if highlighted == segment.id { highlighted = nil }
                        }
                }
                Spacer(minLength: 0)
            }
            .frame(width: g.size.width, alignment: .leading)
            .background(.primary.opacity(0.07))
            .clipShape(Capsule())
            .overlay(alignment: .topLeading) {
                if let i = segments.firstIndex(where: { $0.id == highlighted }) {
                    // A zero-size anchor above the segment's center; the tooltip hangs above it. Kept away from the
                    // edges so a tooltip for the first or last segment stays over the bar.
                    let center = widths[..<i].reduce(0) { $0 + $1 + 2 } + widths[i] / 2
                    Color.clear.frame(width: 0, height: 0)
                        .overlay(alignment: .bottom) {
                            SegmentTooltip(segment: segments[i], share: segments[i].value / max(total, 1), format: format)
                                .padding(.bottom, 8)
                        }
                        .offset(x: min(max(center, 130), max(g.size.width - 130, 130)))
                }
            }
        }
        .frame(height: 14)
        .zIndex(1)  // keep the tooltip above the content around the bar
    }
}

private struct SegmentTooltip: View {
    let segment: SegmentBar.Segment
    let share: Double
    let format: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Circle().fill(segment.color).frame(width: 8, height: 8)
                Text(segment.id).fontWeight(.semibold)
                Spacer(minLength: 12)
                Text("\(format(segment.value)) · \(Int((share * 100).rounded()))%").monospacedDigit().foregroundStyle(.secondary)
            }
            ForEach(segment.details, id: \.self) { line in
                Text(line).font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit().padding(.leading, 14)
            }
        }
        .font(.system(size: 12))
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color.gray.opacity(0.3), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
        .fixedSize()
        .allowsHitTesting(false)
    }
}

extension View {
    /// A legend row that highlights its part of a `SegmentBar` while hovered.
    func highlights(_ id: String, in highlighted: Binding<String?>) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous).fill(.primary.opacity(highlighted.wrappedValue == id ? 0.06 : 0))
                    .padding(.horizontal, -6)
            )
            .contentShape(Rectangle())
            .onHover { inside in
                if inside { highlighted.wrappedValue = id } else if highlighted.wrappedValue == id { highlighted.wrappedValue = nil }
            }
    }
}
