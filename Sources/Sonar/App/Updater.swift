import AppKit

/// Checks GitHub Releases for a newer Sonar and can install it in place. Off unless the user turns it on;
/// this is the only network request Sonar makes.
@MainActor @Observable final class Updater {
    static let shared = Updater()
    static let repo = "vanisov/sonar"

    enum Status: Equatable {
        case idle, checking, upToDate
        case available(String)
        case installing
        case failed(String)
    }

    struct Release {
        let version: String
        let page: URL
        let zip: URL?
    }

    var status: Status = .idle
    var latest: Release?
    var lastChecked: Date? {
        get {
            access(keyPath: \.lastChecked)
            let t = UserDefaults.standard.double(forKey: Prefs.lastUpdateCheck)
            return t > 0 ? Date(timeIntervalSince1970: t) : nil
        }
        set {
            withMutation(keyPath: \.lastChecked) {
                UserDefaults.standard.set(newValue?.timeIntervalSince1970, forKey: Prefs.lastUpdateCheck)
            }
        }
    }

    nonisolated static var currentVersion: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0" }

    /// Checks once a day while enabled. Wakes hourly (with generous tolerance) just to see if a day has passed.
    func startAutomaticChecks() {
        Task {
            while true {
                if Prefs.bool(Prefs.checkForUpdates, default: false),
                    (lastChecked.map { Date().timeIntervalSince($0) > 86_400 } ?? true)
                {
                    await check()
                    if case .available = status, Prefs.bool(Prefs.installUpdates, default: false) { await install() }
                }
                try? await Task.sleep(for: .seconds(3600), tolerance: .seconds(600))
            }
        }
    }

    func check() async {
        status = .checking
        do {
            var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(Self.repo)/releases?per_page=10")!)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let releases = try decoder.decode([GitHubRelease].self, from: data)
            let beta = Prefs.bool(Prefs.betaUpdates, default: false)
            lastChecked = Date()
            guard let newest = releases.first(where: { !$0.draft && (beta || !$0.prerelease) }) else {
                status = .upToDate
                return
            }
            let version = newest.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
            latest = Release(
                version: version, page: newest.htmlUrl,
                zip: newest.assets.first { $0.name == "Sonar.zip" }?.browserDownloadUrl)
            status = Self.isNewer(version, than: Self.currentVersion) ? .available(version) : .upToDate
        } catch {
            status = .failed("Couldn't reach GitHub. Check your connection and try again.")
        }
    }

    /// Downloads the release zip, swaps it in for the running app, and relaunches.
    func install() async {
        guard let zip = latest?.zip else { return }
        let appURL = Bundle.main.bundleURL
        guard appURL.pathExtension == "app" else {
            status = .failed("Updates install into Sonar.app. You're running from source.")
            return
        }
        status = .installing
        do {
            let (download, _) = try await URLSession.shared.download(from: zip)
            let work = FileManager.default.temporaryDirectory.appendingPathComponent("SonarUpdate-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
            let unzip = Process()
            unzip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            unzip.arguments = ["-x", "-k", download.path, work.path]
            try unzip.run()
            unzip.waitUntilExit()
            let newApp = work.appendingPathComponent("Sonar.app")
            guard unzip.terminationStatus == 0,
                Bundle(url: newApp)?.bundleIdentifier == Bundle.main.bundleIdentifier
            else {
                status = .failed("The download wasn't a valid Sonar.app.")
                return
            }
            _ = try FileManager.default.replaceItemAt(appURL, withItemAt: newApp)
            let relaunch = Process()
            relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
            relaunch.arguments = ["-c", "sleep 1; /usr/bin/open \"$0\"", appURL.path]
            try relaunch.run()
            NSApp.terminate(nil)
        } catch {
            status = .failed("Couldn't install the update: \(error.localizedDescription)")
        }
    }

    /// "1.10.0" > "1.9.2"
    nonisolated static func isNewer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }, y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let l = i < x.count ? x[i] : 0, r = i < y.count ? y[i] : 0
            if l != r { return l > r }
        }
        return false
    }

    private struct GitHubRelease: Decodable {
        let tagName: String
        let htmlUrl: URL
        let draft: Bool
        let prerelease: Bool
        let assets: [Asset]
        struct Asset: Decodable {
            let name: String
            let browserDownloadUrl: URL
        }
    }
}
