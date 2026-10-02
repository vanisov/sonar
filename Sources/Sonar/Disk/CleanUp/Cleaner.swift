import SwiftUI

/// Finds space that's safe to reclaim, only when asked, and moves what you pick to the Trash. Nothing is deleted,
/// nothing outside your home folder is touched, and no admin rights are needed.
@MainActor @Observable final class Cleaner {
    /// Kept while the dashboard is open so switching sections doesn't throw away a scan; cleared when it closes.
    static let shared = Cleaner()

    enum Phase: Equatable {
        case idle
        case scanning(String)
        case ready
        case cleaning
        case done(moved: Int64, failed: Int)
    }

    var phase = Phase.idle
    var categories: [CleanCategory] = []
    var selection: Set<URL> = []

    var selectedSize: Int64 {
        categories.flatMap(\.items).filter { selection.contains($0.url) }.reduce(0) { $0 + $1.size }
    }

    func scan() {
        phase = .scanning("")
        categories = []
        selection = []
        let running = NSWorkspace.shared.runningApplications.map { (id: $0.bundleIdentifier, name: $0.localizedName) }
        Task.detached(priority: .utility) {
            for (title, find) in CleanScanner.categories(running: running) {
                // Stop if the dashboard closed (reset) mid-scan.
                guard await MainActor.run(body: { self.isScanning }) else { return }
                await MainActor.run { self.phase = .scanning(title) }
                let category = find()
                await MainActor.run { if self.isScanning { self.add(category) } }
            }
            await MainActor.run { if self.isScanning { self.phase = .ready } }
        }
    }

    private var isScanning: Bool {
        if case .scanning = phase { true } else { false }
    }

    private func add(_ category: CleanCategory) {
        guard !category.items.isEmpty else { return }
        categories.append(category)
        selection.formUnion(category.items.map(\.url))
    }

    func reset() {
        guard phase != .cleaning else { return }
        phase = .idle
        categories = []
        selection = []
    }

    func clean() {
        let picked = categories.flatMap(\.items).filter { selection.contains($0.url) }
        phase = .cleaning
        Task.detached(priority: .userInitiated) {
            var moved: Int64 = 0
            var trashed: Set<URL> = []
            for item in picked {
                do {
                    try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
                    moved += item.size
                    trashed.insert(item.url)
                } catch {}
            }
            let (movedTotal, trashedURLs) = (moved, trashed)
            await MainActor.run {
                for i in self.categories.indices { self.categories[i].items.removeAll { trashedURLs.contains($0.url) } }
                self.categories.removeAll { $0.items.isEmpty }
                self.selection.subtract(trashedURLs)
                self.phase = .done(moved: movedTotal, failed: picked.count - trashedURLs.count)
            }
        }
    }

    func isSelected(_ c: CleanCategory) -> Binding<Bool> {
        Binding(
            get: { c.items.allSatisfy { self.selection.contains($0.url) } },
            set: { on in
                let urls = c.items.map(\.url)
                if on { self.selection.formUnion(urls) } else { self.selection.subtract(urls) }
            })
    }

    func isSelected(_ item: CleanItem) -> Binding<Bool> {
        Binding(
            get: { self.selection.contains(item.url) },
            set: { on in
                if on { self.selection.insert(item.url) } else { self.selection.remove(item.url) }
            })
    }
}
