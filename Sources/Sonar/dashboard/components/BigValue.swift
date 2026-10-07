import SwiftUI

/// A big number with its unit and a caption, e.g. "34.1 %  Usage".
struct BigValue: View {
    let value: String
    var unit = ""
    var caption: String?
    var dot: Color?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(.system(size: 26, weight: .semibold, design: .rounded)).monospacedDigit()
                Text(unit).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
            }
            if let caption {
                HStack(spacing: 5) {
                    if let dot { Circle().fill(dot).frame(width: 7, height: 7) }
                    Text(caption)
                }
                .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
