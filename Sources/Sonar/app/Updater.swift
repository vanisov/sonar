import AppKit
import Security

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
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard code == 200 else {
                status = .failed(
                    code == 403 || code == 429
                        ? "GitHub is limiting requests right now. Sonar will try again later."
                        : "GitHub returned an error (\(code)). Try again later.")
                return
            }
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
        guard status != .installing, let latest, let zip = latest.zip else { return }
        guard zip.scheme == "https", zip.host == "github.com" else {
            status = .failed("The download link didn't point to GitHub.")
            return
        }
        let appURL = Bundle.main.bundleURL
        guard appURL.pathExtension == "app" else {
            status = .failed("Updates install into Sonar.app. You're running from source.")
            return
        }
        status = .installing
        do {
            let (download, _) = try await URLSession.shared.download(from: zip)
            let work = FileManager.default.temporaryDirectory.appendingPathComponent("SonarUpdate-\(UUID().uuidString)")
            defer {
                try? FileManager.default.removeItem(at: download)
                try? FileManager.default.removeItem(at: work)
            }
            try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
            let unzip = Process()
            unzip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            unzip.arguments = ["-x", "-k", download.path, work.path]
            try unzip.run()
            unzip.waitUntilExit()
            let newApp = work.appendingPathComponent("Sonar.app")
            // Only Sonar itself, the version the release says, and never a downgrade or a link to another app.
            let bundle = Bundle(url: newApp)
            let version = bundle?.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
            guard unzip.terminationStatus == 0,
                (try? newApp.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == false,
                bundle?.bundleIdentifier == Bundle.main.bundleIdentifier,
                version == latest.version, Self.isNewer(version, than: Self.currentVersion)
            else {
                status = .failed("The download wasn't a valid Sonar.app.")
                return
            }
            // And signed with the same certificate as this copy, so a release uploaded by anyone else is refused.
            guard Self.isSigned(newApp, likeCodeAt: appURL) else {
                status = .failed("The download isn't signed by Sonar, so it wasn't installed.")
                return
            }
            _ = try FileManager.default.replaceItemAt(appURL, withItemAt: newApp)
            let relaunch = Process()
            relaunch.executableURL = URL(fileURLWithPath: "/bin/sh")
            // Wait for this process to exit, or `open` may just bring the old instance forward.
            relaunch.arguments = [
                "-c", "while kill -0 \"$1\" 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"$0\"", appURL.path, "\(getpid())",
            ]
            try relaunch.run()
            NSApp.terminate(nil)
        } catch {
            status = .failed("Couldn't install the update: \(error.localizedDescription)")
        }
    }

    /// Whether `candidate` satisfies the designated requirement of the app at `reference`: same bundle identifier and
    /// signed with the same certificate. A reference without a certificate (an ad-hoc build from source) has nothing
    /// to compare against, so any valid signature passes; releases are always signed with the certificate.
    nonisolated static func isSigned(_ candidate: URL, likeCodeAt reference: URL) -> Bool {
        var referenceCode: SecStaticCode?, candidateCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(reference as CFURL, [], &referenceCode) == errSecSuccess, let referenceCode,
            SecStaticCodeCreateWithPath(candidate as CFURL, [], &candidateCode) == errSecSuccess, let candidateCode
        else { return false }
        let strict = SecCSFlags(rawValue: kSecCSCheckAllArchitectures | kSecCSStrictValidate)
        var info: CFDictionary?
        SecCodeCopySigningInformation(referenceCode, SecCSFlags(rawValue: kSecCSSigningInformation), &info)
        let certificates = (info as? [String: Any])?[kSecCodeInfoCertificates as String] as? [SecCertificate] ?? []
        guard !certificates.isEmpty else { return SecStaticCodeCheckValidity(candidateCode, strict, nil) == errSecSuccess }
        var requirement: SecRequirement?
        guard SecCodeCopyDesignatedRequirement(referenceCode, [], &requirement) == errSecSuccess, let requirement else { return false }
        return SecStaticCodeCheckValidity(candidateCode, strict, requirement) == errSecSuccess
    }

    /// Semantic versions: "1.10.0" > "1.9.2", and a prerelease is older than its release: "1.5.0-beta.1" < "1.5.0".
    nonisolated static func isNewer(_ a: String, than b: String) -> Bool {
        func parts(_ v: String) -> (core: [Int], pre: [Substring]?) {
            let split = v.split(separator: "-", maxSplits: 1)
            return (
                split.first.map { $0.split(separator: ".").map { Int($0) ?? 0 } } ?? [],
                split.count > 1 ? split[1].split(separator: ".") : nil
            )
        }
        let (x, y) = (parts(a), parts(b))
        for i in 0..<max(x.core.count, y.core.count) {
            let l = i < x.core.count ? x.core[i] : 0, r = i < y.core.count ? y.core[i] : 0
            if l != r { return l > r }
        }
        guard let l = x.pre else { return y.pre != nil }  // same core: a release beats a prerelease
        guard let r = y.pre else { return false }
        for (p, q) in zip(l, r) where p != q {
            if let p = Int(p), let q = Int(q) { return p > q }  // beta.10 > beta.9
            return p > q  // rc > beta
        }
        return l.count > r.count
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
