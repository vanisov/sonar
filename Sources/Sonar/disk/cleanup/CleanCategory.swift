import SwiftUI

/// A file or folder Clean Up can move to the Trash.
struct CleanItem: Identifiable {
    let url: URL
    var name: String
    let size: Int64
    var id: URL { url }
}

struct CleanCategory: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    var items: [CleanItem] = []
    var size: Int64 { items.reduce(0) { $0 + $1.size } }
}
