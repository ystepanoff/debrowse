import AppKit

/// An installed application capable of handling http/https URLs.
struct Browser: Hashable {
    let bundleIdentifier: String
    let name: String
    let url: URL

    init?(url: URL) {
        guard let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier else {
            return nil
        }
        self.bundleIdentifier = identifier
        self.url = url

        var displayName = FileManager.default.displayName(atPath: url.path)
        if displayName.lowercased().hasSuffix(".app") {
            displayName = String(displayName.dropLast(4))
        }
        self.name = displayName
    }

    /// The application's icon, resized to a square of the given point size.
    func icon(size: CGFloat) -> NSImage {
        // Copy before resizing so the instance NSWorkspace caches is left untouched.
        let image = NSWorkspace.shared.icon(forFile: url.path).copy() as! NSImage
        image.size = NSSize(width: size, height: size)
        return image
    }

    // Identity is the bundle identifier; the same browser may live at several paths.
    static func == (lhs: Browser, rhs: Browser) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleIdentifier)
    }
}
