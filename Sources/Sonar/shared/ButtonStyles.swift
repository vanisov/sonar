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
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(.primary.opacity(configuration.isPressed ? 0.07 : hovering ? 0.035 : 0))
                        .allowsHitTesting(false)
                )
                .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .onHover { hovering = $0 }
        }
    }
}

/// A small round icon button, like the panel's Dashboard, Settings and Quit.
struct CircleButtonStyle: ButtonStyle {
    var hoverTint: Color = .primary

    func makeBody(configuration: Configuration) -> some View { Styled(configuration: configuration, hoverTint: hoverTint) }

    private struct Styled: View {
        let configuration: Configuration
        let hoverTint: Color
        @State private var hovering = false

        var body: some View {
            configuration.label
                .labelStyle(.iconOnly)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(hovering ? AnyShapeStyle(hoverTint) : AnyShapeStyle(.secondary))
                .frame(width: 26, height: 26)
                .background(.primary.opacity(configuration.isPressed ? 0.16 : hovering ? 0.11 : 0.06), in: Circle())
                .overlay(Circle().strokeBorder(.primary.opacity(0.07)))
                .contentShape(Circle())
                .onHover { hovering = $0 }
        }
    }
}
