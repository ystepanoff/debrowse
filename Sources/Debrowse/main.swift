import AppKit

// Debugging: `Debrowse --list` prints the detected browsers and exits.
if CommandLine.arguments.contains("--list") {
    let manager = BrowserManager()
    let current = manager.currentDefault()
    print("Default browser: \(current.map { "\($0.name) (\($0.bundleIdentifier))" } ?? "unknown")")
    print("Installed browsers:")
    for browser in manager.installedBrowsers() {
        let marker = browser == current ? "*" : " "
        print("  \(marker) \(browser.name)  [\(browser.bundleIdentifier)]  \(browser.url.path)")
    }
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Menu bar only: no Dock icon, no main window.
app.setActivationPolicy(.accessory)
app.run()
