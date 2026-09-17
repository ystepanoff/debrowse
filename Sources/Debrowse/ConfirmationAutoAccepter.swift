import AppKit
import ApplicationServices

/// The Accessibility permission (System Settings › Privacy & Security › Accessibility). Debrowse
/// needs it for one thing only: pressing the system's confirmation dialogue on the user's behalf.
enum AccessibilityPermission {
    /// The Accessibility pane in System Settings.
    static let settingsPaneURL =
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!

    static var isGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system prompt for the permission, which also lists the app in the Accessibility
    /// pane where the user has to switch it on. macOS may show this prompt only once per app, so
    /// callers should offer their own route to `settingsPaneURL` afterwards.
    static func request() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}

/// Presses "Use <browser>" on the confirmation dialogue macOS shows when the default browser
/// changes, so the switch completes without a click.
///
/// The dialogue belongs to CoreServicesUIAgent and no app can suppress it, but with the
/// Accessibility permission it can be operated. While active, this polls the agent's windows and
/// presses the single button whose title names the browser being switched to. Nothing else is
/// ever pressed: if the dialogue does not look as expected, no button matches, or the match is
/// ambiguous, the dialogue is left to the user.
///
/// All methods must be called on the main thread.
final class ConfirmationAutoAccepter {
    private static let agentBundleIdentifier = "com.apple.coreservices.uiagent"
    private static let pollInterval: TimeInterval = 0.1
    private static let timeout: TimeInterval = 20
    /// Upper bound on how long one Accessibility call may block the main thread.
    private static let messagingTimeout: Float = 0.25
    /// How far below a window to look for buttons. On macOS 26 they are direct children; older
    /// releases have not been checked, so allow for some nesting.
    private static let maxButtonDepth = 3

    private var timer: Timer?
    private var deadline = Date.distantPast
    private var targetNames: [String] = []
    private var otherNames: [String] = []

    deinit {
        stop()
    }

    /// Starts watching for the dialogue that switches to `browser`. `replacing` lists the browsers
    /// currently in charge; they appear on the "Keep" button and are used to break ties when one
    /// name contains the other (e.g. "Google Chrome" vs "Google Chrome for Testing").
    /// Call `stop()` once the change has completed; watching also ends by itself after a timeout.
    /// Does nothing without the Accessibility permission.
    func start(for browser: Browser, replacing others: [Browser]) {
        stop()
        guard AccessibilityPermission.isGranted else { return }

        targetNames = Self.names(of: browser)
        otherNames = others.flatMap(Self.names(of:)).filter { other in
            !targetNames.contains { $0.caseInsensitiveCompare(other) == .orderedSame }
        }
        deadline = Date().addingTimeInterval(Self.timeout)
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), Self.messagingTimeout)

        // Common modes so polling carries on if the menu is opened while the dialogue is up;
        // nothing here touches the menu.
        let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        guard Date() < deadline else {
            stop()
            return
        }
        for agent in NSRunningApplication.runningApplications(withBundleIdentifier: Self.agentBundleIdentifier) {
            let application = AXUIElementCreateApplication(agent.processIdentifier)
            let windows: [AXUIElement] = application.attribute(kAXWindowsAttribute) ?? []
            for window in windows {
                pressAcceptButton(in: window)
            }
        }
    }

    private func pressAcceptButton(in window: AXUIElement) {
        let buttons = Self.buttons(under: window, depth: Self.maxButtonDepth)
        // The dialogue is known to offer exactly two buttons: "Use <target>" and "Keep <current>".
        // Anything else is not the dialogue we are after.
        guard buttons.count == 2 else { return }

        // Only "Use <target>" names the target, unless the current browser's name happens to
        // contain the target's; drop those.
        var matches = buttons.filter { button in
            targetNames.contains { Self.title(button.title, mentions: $0) }
        }
        if matches.count > 1 {
            matches = matches.filter { button in
                !otherNames.contains { Self.title(button.title, mentions: $0) }
            }
        }
        guard matches.count == 1 else { return }

        _ = AXUIElementPerformAction(matches[0].element, kAXPressAction as CFString)
    }

    private static func buttons(under element: AXUIElement, depth: Int) -> [(element: AXUIElement, title: String)] {
        let children: [AXUIElement] = element.attribute(kAXChildrenAttribute) ?? []
        return children.flatMap { child -> [(element: AXUIElement, title: String)] in
            if (child.attribute(kAXRoleAttribute) as String?) == kAXButtonRole {
                return [(child, child.attribute(kAXTitleAttribute) ?? "")]
            }
            return depth > 1 ? buttons(under: child, depth: depth - 1) : []
        }
    }

    /// The names macOS might print for a browser: what Finder shows, plus the bundle's own display
    /// name and name, which differ from the Finder name when the bundle was renamed on disk.
    private static func names(of browser: Browser) -> [String] {
        var names = [browser.name]
        if let bundle = Bundle(url: browser.url) {
            for key in ["CFBundleDisplayName", "CFBundleName"] {
                if let name = bundle.localizedInfoDictionary?[key] as? String { names.append(name) }
                if let name = bundle.infoDictionary?[key] as? String { names.append(name) }
            }
        }
        var seen = Set<String>()
        return names
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
    }

    private static func title(_ title: String, mentions name: String) -> Bool {
        title.range(of: name, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}

private extension AXUIElement {
    /// Reads an attribute, or nil when it is missing, of another type, or the call fails
    /// (for example because the Accessibility permission was withdrawn).
    func attribute<T>(_ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, name as CFString, &value) == .success else { return nil }
        return value as? T
    }
}
