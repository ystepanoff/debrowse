import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    private let manager = BrowserManager()

    private var browsers: [Browser] = []
    private var currentDefault: Browser?
    private var currentHTTPSDefault: Browser?
    private var iconCache: [String: NSImage] = [:]
    private var isChangingDefault = false
    private var isMenuOpen = false
    private var deferredUntilMenuCloses: [() -> Void] = []
    private var refreshTimer: Timer?

    private static let systemSettingsURL =
        URL(string: "x-apple.systempreferences:com.apple.Desktop-Settings.extension")!
    private static let systemSettingsAppURL =
        URL(fileURLWithPath: "/System/Applications/System Settings.app")

    // MARK: - NSApplicationDelegate

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        menu.delegate = self
        menu.autoenablesItems = false
        item.menu = menu

        reload()

        // Pick up changes made elsewhere (System Settings, another tool, a browser's own prompt).
        // Scheduled in the default run loop mode only, so it never fires while the menu is tracking.
        let timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.reloadDefaultsIfChanged()
        }
        timer.tolerance = 1
        refreshTimer = timer
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Double-clicking the app in Finder while it runs: pop the menu so the user sees it.
        if !isMenuOpen {
            statusItem?.button?.performClick(nil)
        }
        return false
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        reload()
    }

    func menuWillOpen(_ menu: NSMenu) {
        isMenuOpen = true
    }

    func menuDidClose(_ menu: NSMenu) {
        isMenuOpen = false
        let blocks = deferredUntilMenuCloses
        deferredUntilMenuCloses.removeAll()
        // Let the menu finish tearing down its tracking session before we touch it again.
        DispatchQueue.main.async {
            blocks.forEach { $0() }
        }
    }

    /// Mutating the menu or running a modal alert while the menu is tracking is unsafe;
    /// queue such work until the menu has closed.
    private func whenMenuIsClosed(_ block: @escaping () -> Void) {
        if isMenuOpen {
            deferredUntilMenuCloses.append(block)
        } else {
            block()
        }
    }

    // MARK: - State

    private func reload() {
        browsers = manager.installedBrowsers()
        refreshDefaults()
        rebuildMenu()
        updateStatusItem()
    }

    private func refreshDefaults() {
        currentDefault = manager.currentDefault()
        currentHTTPSDefault = manager.currentHTTPSDefault()
    }

    private func reloadDefaultsIfChanged() {
        let http = manager.currentDefault()
        let https = manager.currentHTTPSDefault()
        guard http != currentDefault || https != currentHTTPSDefault else { return }
        currentDefault = http
        currentHTTPSDefault = https
        updateStatusItem()
    }

    private var isSplit: Bool {
        currentHTTPSDefault != nil && currentHTTPSDefault != currentDefault
    }

    private func icon(for browser: Browser, size: CGFloat) -> NSImage {
        let key = "\(browser.bundleIdentifier)@\(Int(size))"
        if let cached = iconCache[key] { return cached }
        let image = browser.icon(size: size)
        iconCache[key] = image
        return image
    }

    // MARK: - UI

    private func rebuildMenu() {
        menu.removeAllItems()

        var headerTitle = currentDefault.map { "Default Browser: \($0.name)" } ?? "Default Browser: Unknown"
        if isSplit, let https = currentHTTPSDefault {
            headerTitle += "  (https: \(https.name))"
        }
        let header = NSMenuItem(title: headerTitle, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        if browsers.isEmpty {
            let empty = NSMenuItem(title: "No browsers found", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        }

        for browser in browsers {
            let item = NSMenuItem(title: browser.name, action: #selector(selectBrowser(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = browser
            item.image = icon(for: browser, size: 16)
            item.state = menuState(for: browser)
            item.isEnabled = !isChangingDefault
            item.toolTip = browser.url.path
            menu.addItem(item)
        }

        menu.addItem(.separator())

        let launchAtLogin = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        launchAtLogin.target = self
        switch LoginItem.state {
        case .unavailable:
            launchAtLogin.state = .off
            launchAtLogin.isEnabled = false
            launchAtLogin.toolTip = "Available when running from Debrowse.app"
        case .disabled:
            launchAtLogin.state = .off
        case .enabled:
            launchAtLogin.state = .on
        case .requiresApproval:
            launchAtLogin.state = .mixed
            launchAtLogin.toolTip = "Waiting for your approval in System Settings › Login Items. Click to open it."
        }
        menu.addItem(launchAtLogin)

        let showIcon = NSMenuItem(title: "Show Browser Icon in Menu Bar", action: #selector(toggleShowBrowserIcon(_:)), keyEquivalent: "")
        showIcon.target = self
        showIcon.state = Preferences.showBrowserIcon ? .on : .off
        menu.addItem(showIcon)

        let settings = NSMenuItem(title: "Open System Settings…", action: #selector(openSystemSettings(_:)), keyEquivalent: "")
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Debrowse", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
    }

    /// Checkmark when the browser handles both schemes, a dash when it handles only one.
    private func menuState(for browser: Browser) -> NSControl.StateValue {
        let handlesHTTP = browser == currentDefault
        let handlesHTTPS = browser == currentHTTPSDefault
        if handlesHTTP && handlesHTTPS { return .on }
        if handlesHTTP || handlesHTTPS { return .mixed }
        return .off
    }

    private func updateStatusItem() {
        guard let button = statusItem?.button else { return }

        if Preferences.showBrowserIcon, let current = currentDefault {
            let image = icon(for: current, size: 18)
            image.isTemplate = false
            button.image = image
        } else {
            let image = NSImage(systemSymbolName: "globe", accessibilityDescription: "Default browser")
            image?.isTemplate = true
            button.image = image
        }
        // Never let the item collapse to nothing; without a Dock icon it would be unreachable.
        button.title = button.image == nil ? "Debrowse" : ""

        var tooltip = currentDefault.map { "Default browser: \($0.name)" } ?? "Debrowse"
        if isSplit, let https = currentHTTPSDefault {
            tooltip += "\nhttps links open in \(https.name)"
        }
        button.toolTip = tooltip
    }

    // MARK: - Actions

    @objc private func selectBrowser(_ sender: NSMenuItem) {
        guard let browser = sender.representedObject as? Browser else { return }
        let alreadyDefault = browser == currentDefault && browser == currentHTTPSDefault
        guard !alreadyDefault, !isChangingDefault else { return }

        isChangingDefault = true
        manager.setDefault(browser) { [weak self] outcome in
            guard let self else { return }
            self.isChangingDefault = false
            self.refreshDefaults()
            self.updateStatusItem()

            self.whenMenuIsClosed { [weak self] in
                guard let self else { return }
                switch outcome {
                case .changed, .cancelled:
                    break
                case .partiallyChanged(let error):
                    let httpsName = self.currentHTTPSDefault?.name ?? "another browser"
                    var message = "http links now open in \(browser.name), but https links still open in \(httpsName). "
                        + "Choose \(browser.name) again to retry, or fix it in System Settings › Desktop & Dock."
                    if let error {
                        message += "\n\n\(error.localizedDescription)"
                    }
                    self.presentError(title: "Default browser only partially changed", message: message)
                case .failed(let error):
                    self.presentError(
                        title: "Couldn't make \(browser.name) the default browser",
                        message: error.localizedDescription
                    )
                }
            }
        }
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        do {
            try LoginItem.toggle()
        } catch {
            presentError(title: "Couldn't update Login Items", message: error.localizedDescription)
        }
    }

    @objc private func toggleShowBrowserIcon(_ sender: NSMenuItem) {
        Preferences.showBrowserIcon.toggle()
        updateStatusItem()
    }

    @objc private func openSystemSettings(_ sender: NSMenuItem) {
        if !NSWorkspace.shared.open(Self.systemSettingsURL) {
            NSWorkspace.shared.open(Self.systemSettingsAppURL)
        }
    }

    private func presentError(title: String, message: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
