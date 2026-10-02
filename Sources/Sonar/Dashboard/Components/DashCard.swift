import SwiftUI

/// A dashboard card: quiet fill so the numbers carry the page.
struct DashCard<Content: View>: View {
    var title: String?
    var symbol: String?
    var tint: Color = .secondary
    var trailing: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                HStack(spacing: 7) {
                    if let symbol { Image(systemName: symbol).foregroundStyle(tint) }
                    Text(title).foregroundStyle(.secondary)
                    Spacer(minLength: 6)
                    if let trailing { Text(trailing).foregroundStyle(.tertiary).font(.caption) }
                }
                .font(.subheadline.weight(.semibold))
            }
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(.primary.opacity(0.07)))
    }
}
