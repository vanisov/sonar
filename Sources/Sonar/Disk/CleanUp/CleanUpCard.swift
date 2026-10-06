import SwiftUI

/// The Clean Up page.
struct CleanUpCard: View {
    private var cleaner = Cleaner.shared
    @State private var expanded: Set<String> = []

    var body: some View {
        DashCard(title: "Safe to remove", symbol: "sparkles", tint: .signal) {
            switch cleaner.phase {
            case .idle:
                HStack {
                    Text("Find caches, logs and build leftovers that are safe to remove. Nothing is deleted until you empty the Trash.")
                        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 16)
                    Button("Scan") { cleaner.scan() }.buttonStyle(.borderedProminent).tint(.signal)
                }
            default:
                if case .done(let moved, let failed) = cleaner.phase { doneBanner(moved: moved, failed: failed) }
                list
                footer
            }
        }
        #if DEBUG
            .onAppear { if CommandLine.arguments.contains("--scan") { cleaner.scan() } }  // README screenshots
        #endif
    }

    private var list: some View {
        VStack(spacing: 0) {
            ForEach(cleaner.categories) { c in
                if c.id != cleaner.categories.first?.id { Divider() }
                categoryRow(c)
                if expanded.contains(c.id) {
                    ForEach(c.items.prefix(100)) { item in itemRow(item) }
                    if c.items.count > 100 {
                        Text("and \(c.items.count - 100) more").font(.caption).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 56).padding(.vertical, 4)
                    }
                }
            }
            if case .scanning(let what) = cleaner.phase {
                if !cleaner.categories.isEmpty { Divider() }
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(what.isEmpty ? "Scanning…" : "Scanning \(what)…").foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 8)
            } else if cleaner.categories.isEmpty {
                Text("Nothing to clean up.").foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(
                    .vertical, 6)
            }
        }
    }

    private func categoryRow(_ c: CleanCategory) -> some View {
        HStack(spacing: 10) {
            Toggle("", isOn: cleaner.isSelected(c)).toggleStyle(.checkbox).labelsHidden()
            Image(systemName: c.symbol).foregroundStyle(.secondary).frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(c.title)
                Text(c.detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            Text(Fmt.storage(c.size)).monospacedDigit()
            Button {
                if expanded.contains(c.id) { expanded.remove(c.id) } else { expanded.insert(c.id) }
            } label: {
                Image(systemName: "chevron.right").rotationEffect(.degrees(expanded.contains(c.id) ? 90 : 0))
                    .frame(width: 20, height: 20).contentShape(Rectangle())
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
            .help(expanded.contains(c.id) ? "Hide items" : "Show \(c.items.count) items")
        }
        .padding(.vertical, 7)
    }

    private func itemRow(_ item: CleanItem) -> some View {
        HStack(spacing: 10) {
            Toggle("", isOn: cleaner.isSelected(item)).toggleStyle(.checkbox).labelsHidden().controlSize(.small)
            Text(item.name).lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 12)
            Text(Fmt.storage(item.size)).font(.callout).foregroundStyle(.secondary).monospacedDigit()
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.plain).foregroundStyle(.secondary).help("Show in Finder")
            .frame(width: 20)
        }
        .padding(.leading, 28).padding(.vertical, 3)
    }

    private var footer: some View {
        HStack {
            Button("Scan Again") { cleaner.scan() }.disabled(isBusy)
            Spacer()
            Button(cleaner.selection.isEmpty ? "Move to Trash" : "Move \(Fmt.storage(cleaner.selectedSize)) to Trash") { cleaner.clean() }
                .buttonStyle(.borderedProminent).tint(.signal)
                .disabled(cleaner.selection.isEmpty || isBusy)
        }
        .padding(.top, 4)
    }

    private var isBusy: Bool {
        switch cleaner.phase {
        case .scanning, .cleaning: true
        default: false
        }
    }

    private func doneBanner(moved: Int64, failed: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).font(.title3)
            VStack(alignment: .leading, spacing: 1) {
                Text("Moved \(Fmt.storage(moved)) to the Trash.")
                Text(
                    failed > 0
                        ? "\(failed) item\(failed == 1 ? "" : "s") were in use or couldn't be moved. Empty the Trash to free the space."
                        : "Empty the Trash to free the space. Until then, you can put anything back."
                )
                .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Open Trash") {
                if let trash = FileManager.default.urls(for: .trashDirectory, in: .userDomainMask).first { NSWorkspace.shared.open(trash) }
            }
        }
        .padding(10)
        .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
