import SwiftUI

struct PanelSettingsPane: View {
    @AppStorage(Prefs.panelCards) private var cardsRaw = PanelCard.defaults
    @AppStorage(Prefs.panelTopApps) private var topApps = 5
    @AppStorage(Prefs.panelSparkline) private var sparkline = 60
    @AppStorage(Prefs.panelCardClick) private var cardOpens = true

    var body: some View {
        let order = PanelCard.order
        Form {
            Section("Cards · drag to reorder") {
                List {
                    ForEach(order) { card in
                        HStack(spacing: 10) {
                            Image(systemName: card.symbol).frame(width: 18).foregroundStyle(card.tint)
                            Text(card.title)
                            Spacer()
                            Toggle("Show", isOn: shownBinding(card)).labelsHidden().toggleStyle(.switch).controlSize(.small)
                        }
                    }
                    .onMove { from, to in
                        var cards = order
                        cards.move(fromOffsets: from, toOffset: to)
                        let shown = Set(PanelCard.enabled)
                        cardsRaw = PanelCard.encode(order: cards, shown: shown)
                    }
                }
                .frame(height: CGFloat(order.count) * 34)
            }
            Section {
                Picker("Top apps", selection: $topApps) {
                    Text("3").tag(3)
                    Text("5").tag(5)
                    Text("10").tag(10)
                }
                .pickerStyle(.segmented)
                Picker("Sparkline length", selection: $sparkline) {
                    Text("1 min").tag(30)
                    Text("2 min").tag(60)
                    Text("5 min").tag(150)
                }
                .pickerStyle(.segmented)
                Toggle("Clicking a card opens its dashboard page", isOn: $cardOpens)
            }
        }
        .formStyle(.grouped)
        .frame(height: 500)
    }

    private func shownBinding(_ card: PanelCard) -> Binding<Bool> {
        Binding {
            PanelCard.enabled.contains(card)
        } set: { on in
            var shown = Set(PanelCard.enabled)
            if on { shown.insert(card) } else { shown.remove(card) }
            cardsRaw = PanelCard.encode(order: PanelCard.order, shown: shown)
        }
    }
}
