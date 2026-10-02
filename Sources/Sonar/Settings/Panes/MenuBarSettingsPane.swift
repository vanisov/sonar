import SwiftUI

struct MenuBarSettingsPane: View {
    @AppStorage(Prefs.menuBarItems) private var enabledRaw = MenuBarItem.defaults
    @AppStorage(Prefs.menuBarOrder) private var orderRaw = ""
    @AppStorage(Prefs.menuBarStyles) private var stylesRaw = ""
    @AppStorage(Prefs.menuBarDecimals) private var decimals = 0
    @AppStorage(Prefs.menuBarHighlight) private var highlight = true

    var body: some View {
        let order = MenuBarConfig.order
        Form {
            Section {
                HStack {
                    Spacer()
                    Image(nsImage: MenuBarConfig.previewImage())
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .accessibilityLabel("Menu bar preview")
            } header: {
                Text("Preview")
            } footer: {
                Text("With nothing turned on, the menu bar shows the Sonar logo.").foregroundStyle(.secondary)
            }
            Section("Stats · drag to reorder") {
                List {
                    ForEach(order) { item in
                        HStack(spacing: 10) {
                            Image(systemName: item.symbol).frame(width: 18).foregroundStyle(.secondary)
                            Text(item.title)
                            Spacer()
                            Picker("Style", selection: styleBinding(item)) {
                                ForEach(MenuBarItem.Style.allCases, id: \.self) { Text($0.title).tag($0) }
                            }
                            .labelsHidden()
                            .fixedSize()
                            Toggle("Show", isOn: enabledBinding(item)).labelsHidden().toggleStyle(.switch).controlSize(.small)
                        }
                    }
                    .onMove { from, to in
                        var items = order
                        items.move(fromOffsets: from, toOffset: to)
                        orderRaw = items.map(\.rawValue).joined(separator: ",")
                    }
                }
                .frame(height: CGFloat(order.count) * 34)
            }
            Section {
                Picker("Decimal places", selection: $decimals) {
                    Text("None").tag(0)
                    Text("One").tag(1)
                }
                .pickerStyle(.segmented)
                Toggle("Color values that need attention", isOn: $highlight)
            } footer: {
                Text("Orange above 80% CPU or 194 °F (90 °C); red above 95% or 212 °F (100 °C). Memory follows memory pressure.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(height: 560)
    }

    private func enabledBinding(_ item: MenuBarItem) -> Binding<Bool> {
        Binding {
            MenuBarConfig.enabled.contains(item)
        } set: { on in
            var set = MenuBarConfig.enabled
            if on { set.insert(item) } else { set.remove(item) }
            enabledRaw = set.map(\.rawValue).sorted().joined(separator: ",")
        }
    }

    private func styleBinding(_ item: MenuBarItem) -> Binding<MenuBarItem.Style> {
        Binding {
            MenuBarConfig.style(item)
        } set: { style in
            var styles = MenuBarConfig.styles
            styles[item] = style
            stylesRaw = styles.map { "\($0.key.rawValue)=\($0.value.rawValue)" }.sorted().joined(separator: ",")
        }
    }
}
