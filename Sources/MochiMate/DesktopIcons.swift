import AppKit

struct DesktopIcon {
    let name: String
    var center: CGPoint   // global Cocoa coordinates (origin bottom-left of the primary screen)
}

/// Reads and moves the real Finder desktop icons through AppleScript.
/// Finder's `desktop position` uses a top-left origin on the primary screen.
final class DesktopIcons {
    private let queue = DispatchQueue(label: "mochimate.finder")
    private(set) var icons: [DesktopIcon] = []
    /// Finder's desktop "Sort By" setting; anything other than "not arranged" pins icons in place.
    private(set) var arrangement = "not arranged"
    private(set) var lastError: String?

    private var refreshing = false

    var iconsArePinned: Bool { arrangement != "not arranged" && arrangement != "snap to grid" }

    // MARK: Coordinates

    private var primaryHeight: CGFloat { NSScreen.screens.first?.frame.height ?? 0 }
    private func toFinder(_ p: CGPoint) -> (Int, Int) { (Int(p.x.rounded()), Int((primaryHeight - p.y).rounded())) }
    private func fromFinder(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: primaryHeight - y) }

    // MARK: Reading

    func refresh(completion: (() -> Void)? = nil) {
        // Never queue up reads behind one Finder hasn't answered yet (e.g. a pending permission prompt).
        guard !refreshing else { return }
        refreshing = true
        let script = """
        tell application "Finder"
            set out to (arrangement of icon view options of window of desktop as text) & linefeed
            set theItems to every item of desktop
            repeat with anItem in theItems
                set p to desktop position of anItem
                set out to out & (name of anItem) & tab & (item 1 of p) & tab & (item 2 of p) & linefeed
            end repeat
            return out
        end tell
        """
        run(script) { [weak self] result in
            guard let self else { return }
            self.refreshing = false
            switch result {
            case .failure(let error):
                self.lastError = error.localizedDescription
            case .success(let output):
                self.lastError = nil
                var lines = output.split(separator: "\n", omittingEmptySubsequences: true)
                if !lines.isEmpty { self.arrangement = String(lines.removeFirst()) }
                self.icons = lines.compactMap { line in
                    let parts = line.split(separator: "\t")
                    // Finder reports -1,-1 for icons it is auto-arranging.
                    guard parts.count == 3, let x = Double(parts[1]), let y = Double(parts[2]), x >= 0 || y >= 0 else { return nil }
                    return DesktopIcon(name: String(parts[0]), center: self.fromFinder(x, y))
                }
            }
            completion?()
        }
    }

    // MARK: Moving

    /// Moves an icon through a list of points (one Finder call), then reports where it really ended up.
    func move(_ name: String, along path: [CGPoint], stepDelay: Double = 0.02,
              completion: ((CGPoint?) -> Void)? = nil) {
        moveAll([name: path], stepDelay: stepDelay) { completion?($0[name]) }
    }

    /// Moves several icons together, a step along each path at a time (one Finder call),
    /// then reports where each really ended up.
    func moveAll(_ paths: [String: [CGPoint]], stepDelay: Double = 0.02,
                 completion: (([String: CGPoint]) -> Void)? = nil) {
        let entries = paths.filter { !$0.value.isEmpty }.map { (name: $0.key, path: $0.value) }
        guard !entries.isEmpty else { completion?([:]); return }
        let items = entries.indices.map { "set icon\($0) to item \"\(escape(entries[$0].name))\" of desktop" }
        let steps = (0..<entries.map(\.path.count).max()!).map { step in
            entries.indices.compactMap { i -> String? in
                guard step < entries[i].path.count else { return nil }
                let (x, y) = toFinder(entries[i].path[step])
                return "set desktop position of icon\(i) to {\(x), \(y)}"
            }.joined(separator: "\n")
        }
        let reads = entries.indices.map {
            "set p to desktop position of icon\($0)\nset out to out & ((item 1 of p) as text) & tab & ((item 2 of p) as text) & linefeed"
        }
        let script = """
        tell application "Finder"
        \(items.joined(separator: "\n"))
        \(steps.joined(separator: "\ndelay \(stepDelay)\n"))
        set out to ""
        \(reads.joined(separator: "\n"))
        return out
        end tell
        """
        run(script) { [weak self] result in
            guard let self else { return }
            var finals: [String: CGPoint] = [:]
            if case .success(let output) = result {
                for (entry, line) in zip(entries, output.split(separator: "\n")) {
                    let parts = line.split(separator: "\t")
                    guard parts.count == 2, let x = Double(parts[0]), let y = Double(parts[1]) else { continue }
                    let point = self.fromFinder(x, y)
                    finals[entry.name] = point
                    if let i = self.icons.firstIndex(where: { $0.name == entry.name }) { self.icons[i].center = point }
                }
            }
            completion?(finals)
        }
    }

    /// Turns off the desktop "Sort By" setting so icons can be moved. Only called on explicit user request.
    func disableAutoArrange(completion: @escaping () -> Void) {
        run("""
        tell application "Finder" to set arrangement of icon view options of window of desktop to not arranged
        """) { [weak self] _ in self?.refresh(completion: completion) }
    }

    // MARK: AppleScript plumbing

    private func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    /// Whether the user has already been asked to let MochiMate control Finder (only touched on `queue`).
    private var askedForPermission = false

    /// Only checks, so Finder calls never wait on the user. The first time consent is needed the prompt is
    /// raised on another thread: it blocks for as long as it is on screen (or for good if it never shows),
    /// and a grant made there or later in System Settings is picked up by the next check.
    private func finderPermission() -> OSStatus {
        let status = Self.determinePermission(ask: false)
        if status == OSStatus(errAEEventWouldRequireUserConsent) && !askedForPermission {
            askedForPermission = true
            DispatchQueue.global().async { _ = Self.determinePermission(ask: true) }
        }
        return status
    }

    private static func determinePermission(ask: Bool) -> OSStatus {
        var target = AEAddressDesc()
        let bundleID = "com.apple.finder"
        _ = bundleID.withCString { AECreateDesc(typeApplicationBundleID, $0, strlen($0), &target) }
        defer { AEDisposeDesc(&target) }
        return AEDeterminePermissionToAutomateTarget(&target, typeWildCard, typeWildCard, ask)
    }

    private func run(_ script: String, completion: @escaping (Result<String, Error>) -> Void) {
        queue.async {
            let permission = self.finderPermission()
            guard permission == noErr || permission == OSStatus(procNotFound) else {
                let error = NSError(domain: "Finder", code: Int(permission), userInfo: [
                    NSLocalizedDescriptionKey: ui(.finderNotAllowed, "\(permission)"),
                ])
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            let out = Pipe(), err = Pipe()
            process.standardOutput = out
            process.standardError = err
            let result: Result<String, Error>
            // Give up on a Finder call that hangs so later moves don't wait behind it forever.
            let timeout = DispatchWorkItem { if process.isRunning { process.terminate() } }
            do {
                try process.run()
                DispatchQueue.global().asyncAfter(deadline: .now() + 10, execute: timeout)
                let data = out.fileHandleForReading.readDataToEndOfFile()
                let errData = err.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                timeout.cancel()
                if process.terminationStatus == 0 {
                    result = .success(String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines))
                } else {
                    let message = String(decoding: errData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                    result = .failure(NSError(domain: "Finder", code: Int(process.terminationStatus),
                                              userInfo: [NSLocalizedDescriptionKey: message]))
                }
            } catch {
                result = .failure(error)
            }
            DispatchQueue.main.async { completion(result) }
        }
    }
}
