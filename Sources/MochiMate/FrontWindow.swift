import AppKit

/// The frontmost app's main window, for the pet to perch on. Only its position and the app's name are read
/// (no window titles or contents, so no Screen Recording permission is needed).
struct FrontWindow {
    /// Global Cocoa coordinates (origin bottom-left of the primary screen).
    let frame: CGRect
    let app: String

    static func current() -> FrontWindow? {
        guard let front = NSWorkspace.shared.frontmostApplication,
              front.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return nil }
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        // Listed front to back: the first normal-level window of the app is the one on top.
        for info in list {
            guard info[kCGWindowOwnerPID as String] as? pid_t == front.processIdentifier,
                  info[kCGWindowLayer as String] as? Int == 0,
                  let dict = info[kCGWindowBounds as String] as! CFDictionary?,
                  let bounds = CGRect(dictionaryRepresentation: dict),
                  bounds.width >= 240, bounds.height >= 160 else { continue }
            // Window bounds use a top-left origin on the primary screen.
            let frame = CGRect(x: bounds.minX, y: primaryHeight - bounds.maxY, width: bounds.width, height: bounds.height)
            return FrontWindow(frame: frame, app: front.localizedName ?? "app")
        }
        return nil
    }
}
