import SwiftUI

/// Plain button with a hover highlight, so it reads as clickable.
struct HoverButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { Styled(configuration: configuration) }

    private struct Styled: View {
        let configuration: Configuration
        @State private var hovering = false

        var body: some View {
            configuration.label
                .padding(.horizontal, 8).padding(.vertical, 5)
                .foregroundStyle(hovering ? .primary : .secondary)
                .background(
                    .primary.opacity(configuration.isPressed ? 0.14 : hovering ? 0.08 : 0),
                    in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                )
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .onHover { hovering = $0 }
        }
    }
}

/// A whole card as a button: lightens on hover, darkens while pressed.
struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { Styled(configuration: configuration) }

    private struct Styled: View {
        let configuration: Configuration
        @State private var hovering = false

        var body: some View {
            configuration.label
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.primary.opacity(configuration.isPressed ? 0.07 : hovering ? 0.035 : 0))
                        .allowsHitTesting(false)
                )
                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .onHover { hovering = $0 }
        }
    }
}
