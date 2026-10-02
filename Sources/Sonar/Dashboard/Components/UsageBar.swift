import SwiftUI

struct UsageBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        LevelBar(fraction: fraction, color: color, cornerRadius: 4).frame(height: 8)
    }
}
