import AppKit

/// Checks GitHub Releases for two things:
/// - a new app version: a release tagged vX.Y with a .dmg, installed in one click (downloads the DMG, copies the app
///   out, then a small script swaps it in once the app has quit and opens the new one);
/// - a new content pack: an asset named `mochimate-content-<N>.zip` (dialogue and audio) on any release, installed
///   silently into Application Support when N is higher than the pack in use. Content can ship without an app release.
final class Updater: ObservableObject {
    enum State: Equatable {
        case idle, checking, upToDate, installing
        case available(version: String, dmg: URL)
        case failed(String)
    }

    static let repository = "khdev3jk/MochiMate"
    private static let releases = URL(string: "https://api.github.com/repos/\(repository)/releases?per_page=30")!
    private static let contentAsset = #/mochimate-content-(\d+)\.zip/#

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// Only a packaged MochiMate.app can replace itself (not `swift run`).
    static var canUpdate: Bool { Bundle.main.bundleURL.pathExtension == "app" }

    @Published private(set) var state: State = .idle
    @Published private(set) var contentVersion = ContentStore.shared.pack.version
    /// Called on the main thread after an install fails, with the reason.
    var onInstallFailed: ((String) -> Void)?
    /// Called on the main thread after a new content pack was installed.
    var onContentInstalled: (() -> Void)?
    private var timer: Timer?

    private struct Release: Decodable {
        struct Asset: Decodable {
            let name: String
            let url: URL
            enum CodingKeys: String, CodingKey { case name, url = "browser_download_url" }
        }
        let tagName: String
        let draft: Bool
        let prerelease: Bool
        let assets: [Asset]
        enum CodingKeys: String, CodingKey { case tagName = "tag_name", draft, prerelease, assets }
    }

    /// Checks now and every 6 hours while automatic updates are on.
    func startAutomaticChecks() {
        if Settings.shared.autoUpdate { check() }
        let timer = Timer(timeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            if Settings.shared.autoUpdate { self?.check() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func check() {
        switch state {
        case .checking, .installing: return
        default: break
        }
        state = .checking
        var request = URLRequest(url: Self.releases)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { data, _, error in
            guard let data, let releases = try? JSONDecoder().decode([Release].self, from: data) else {
                let message = error?.localizedDescription ?? "Could not read the releases"
                DispatchQueue.main.async { self.state = .failed(message) }
                return
            }
            let published = releases.filter { !$0.draft && !$0.prerelease }
            self.checkContent(in: published)
            // Newest app release first: highest vX.Y tag that has a DMG.
            let app = published.compactMap { release -> (String, URL)? in
                guard release.tagName.hasPrefix("v"), let dmg = release.assets.first(where: { $0.name.hasSuffix(".dmg") })
                else { return nil }
                return (String(release.tagName.dropFirst()), dmg.url)
            }.max { Self.isNewer($1.0, than: $0.0) }
            let result: State
            if let (version, dmg) = app, Self.isNewer(version, than: Self.currentVersion) {
                result = .available(version: version, dmg: dmg)
            } else {
                result = .upToDate
            }
            DispatchQueue.main.async { self.state = result }
        }.resume()
    }

    // MARK: App

    func install() {
        guard case .available(_, let dmg) = state, Self.canUpdate else { return }
        let target = Bundle.main.bundleURL
        guard FileManager.default.isWritableFile(atPath: target.deletingLastPathComponent().path) else {
            return fail(ui(.updateNoPermission, target.deletingLastPathComponent().path))
        }
        state = .installing
        URLSession.shared.downloadTask(with: dmg) { file, _, error in
            // The downloaded file is deleted once this handler returns, so everything happens in here.
            guard let file else { return self.fail(error?.localizedDescription ?? "Download failed") }
            do {
                let newApp = try Self.extractApp(fromDMG: file)
                try Self.swapInWhenQuit(newApp, replacing: target)
                DispatchQueue.main.async { NSApp.terminate(nil) }
            } catch {
                self.fail(error.localizedDescription)
            }
        }.resume()
    }

    private func fail(_ message: String) {
        DispatchQueue.main.async {
            self.state = .failed(message)
            self.onInstallFailed?(message)
        }
    }

    /// "1.10" is newer than "1.9"; missing parts count as 0.
    static func isNewer(_ version: String, than current: String) -> Bool {
        let a = version.split(separator: ".").map { Int($0) ?? 0 }, b = current.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    /// Mounts the DMG, copies the .app inside it to a temporary folder and returns where it went.
    private static func extractApp(fromDMG file: URL) throws -> URL {
        let work = FileManager.default.temporaryDirectory.appendingPathComponent("MochiMate-update-\(UUID().uuidString)")
        let mount = work.appendingPathComponent("mount")
        try FileManager.default.createDirectory(at: mount, withIntermediateDirectories: true)
        let dmg = work.appendingPathComponent("update.dmg")
        try FileManager.default.moveItem(at: file, to: dmg)
        try run("/usr/bin/hdiutil", "attach", dmg.path, "-nobrowse", "-readonly", "-mountpoint", mount.path)
        defer { try? run("/usr/bin/hdiutil", "detach", mount.path, "-force") }
        guard let app = try FileManager.default.contentsOfDirectory(at: mount, includingPropertiesForKeys: nil)
            .first(where: { $0.pathExtension == "app" }) else {
            throw NSError(domain: "Updater", code: 1, userInfo: [NSLocalizedDescriptionKey: "No app inside the DMG"])
        }
        let copy = work.appendingPathComponent(app.lastPathComponent)
        try run("/usr/bin/ditto", app.path, copy.path)
        return copy
    }

    /// Starts a detached script that waits for this process to exit, replaces `target` with `newApp` and opens it.
    private static func swapInWhenQuit(_ newApp: URL, replacing target: URL) throws {
        let script = """
        while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done
        rm -rf "$1" && /usr/bin/ditto "$2" "$1" && /usr/bin/xattr -dr com.apple.quarantine "$1"
        /usr/bin/open "$1"
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script, "sh", target.path, newApp.path]
        try process.run()
    }

    // MARK: Content

    /// Installs the highest-numbered content pack when it beats the one in use (runs on a background queue).
    private func checkContent(in releases: [Release]) {
        let best = releases.flatMap(\.assets).compactMap { asset -> (Int, URL)? in
            guard let match = asset.name.wholeMatch(of: Self.contentAsset), let number = Int(match.1) else { return nil }
            return (number, asset.url)
        }.max { $0.0 < $1.0 }
        guard let (version, url) = best, version > ContentStore.shared.pack.version else { return }
        URLSession.shared.downloadTask(with: url) { file, _, _ in
            guard let file, (try? Self.installContent(zip: file, version: version)) != nil else { return }
            DispatchQueue.main.async {
                ContentStore.shared.reload()
                self.contentVersion = ContentStore.shared.pack.version
                self.onContentInstalled?()
            }
        }.resume()
    }

    /// Unzips a pack, checks that its content.json loads and carries the advertised version, then swaps it in.
    private static func installContent(zip file: URL, version: Int) throws {
        let fm = FileManager.default
        let work = fm.temporaryDirectory.appendingPathComponent("MochiMate-content-\(UUID().uuidString)")
        let unpacked = work.appendingPathComponent("Content")
        try fm.createDirectory(at: unpacked, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: work) }
        try run("/usr/bin/ditto", "-x", "-k", file.path, unpacked.path)
        guard let pack = ContentStore.load(from: unpacked), pack.version == version else {
            throw NSError(domain: "Updater", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid content pack"])
        }
        let target = ContentStore.installedDirectory
        try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: target.path) {
            _ = try fm.replaceItemAt(target, withItemAt: unpacked)
        } else {
            try fm.moveItem(at: unpacked, to: target)
        }
    }

    private static func run(_ tool: String, _ arguments: String...) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        let errors = Pipe()
        process.standardError = errors
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw NSError(domain: "Updater", code: Int(process.terminationStatus), userInfo: [
                NSLocalizedDescriptionKey: "\((tool as NSString).lastPathComponent) failed: \(message)",
            ])
        }
    }
}
