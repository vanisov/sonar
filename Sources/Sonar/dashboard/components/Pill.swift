import SwiftUI

struct Pill: View {
    let text: String
    var color: Color = .signal

    var body: some View {
        Text(text).font(.caption.weight(.semibold)).padding(.horizontal, 8).padding(.vertical, 3)
            .foregroundStyle(color).background(color.opacity(0.15), in: Capsule())
    }
}
