import SwiftUI

/// This version's section of CHANGELOG.md, bundled into Sonar.app by bundle.sh.
enum ReleaseNotes {
    static let current: String? = {
        guard let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md"),
            let text = try? String(contentsOf: url, encoding: .utf8)
        else { return nil }
        let version = Updater.currentVersion
        var lines: [String] = []
        var inSection = false
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.hasPrefix("## [") {
                if inSection { break }
                inSection = line.hasPrefix("## [\(version)]")
                continue
            }
            guard inSection, !line.hasPrefix("[") else { continue }
            lines.append(
                line.hasPrefix("### ") ? String(line.dropFirst(4)) : line.hasPrefix("- ") ? "• " + line.dropFirst(2) : String(line))
        }
        let notes = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return notes.isEmpty ? nil : notes
    }()
}
