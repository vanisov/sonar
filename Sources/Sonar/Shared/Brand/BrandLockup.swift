import SwiftUI

/// Icon + wordmark lockup for the dashboard sidebar.
struct BrandLockup: View {
    var body: some View {
        HStack(spacing: 8) {
            AppMark(size: 22)
            // A fixed label color at partial opacity: the sidebar's vibrant `.primary` washed it out too far.
            Wordmark().fill(Color(nsColor: .labelColor).opacity(0.55)).frame(width: 13 * Wordmark.aspectRatio, height: 13)
        }
        .accessibilityElement()
        .accessibilityLabel("Sonar")
    }
}
