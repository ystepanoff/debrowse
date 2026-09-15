import AppKit

/// Result of asking the system to change the default browser.
enum SetDefaultOutcome {
    /// Both `http` and `https` now point at the requested browser.
    case changed
    /// The user declined the system prompt; nothing changed.
    case cancelled
    /// `http` changed but `https` did not (the user declined the second prompt or it failed).
    /// The system is now in a split state that the user should know about.
    case partiallyChanged(Error?)
    /// Nothing changed because of an error.
    case failed(Error)
}

/// Discovers installed browsers and reads/sets the system default via Launch Services.
/// All methods are expected to be called on the main thread; completions arrive on it too.
final class BrowserManager {
    private static let httpProbe = URL(string: "http://example.com/")!
    private static let httpsProbe = URL(string: "https://example.com/")!

    /// Applications registered for both `http` and `https`, deduplicated by bundle identifier
    /// and sorted by name. Mirrors the list System Settings offers for "Default web browser".
    /// Whatever currently handles either scheme is always included, even if it only claims one.
    func installedBrowsers() -> [Browser] {
        let workspace = NSWorkspace.shared
        let httpsIdentifiers = Set(
            workspace.urlsForApplications(toOpen: Self.httpsProbe)
                .compactMap { Bundle(url: $0)?.bundleIdentifier }
        )

        var seen = Set<String>()
        var browsers: [Browser] = []
        for url in workspace.urlsForApplications(toOpen: Self.httpProbe) {
            guard let browser = Browser(url: url) else { continue }
            guard browser.bundleIdentifier != Bundle.main.bundleIdentifier else { continue }
            guard httpsIdentifiers.contains(browser.bundleIdentifier) else { continue }
            guard seen.insert(browser.bundleIdentifier).inserted else { continue }
            browsers.append(browser)
        }

        for handler in [currentDefault(), currentHTTPSDefault()].compactMap({ $0 })
        where seen.insert(handler.bundleIdentifier).inserted {
            browsers.append(handler)
        }

        return browsers.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    /// The application currently handling `http` URLs. This is what macOS calls the default browser.
    func currentDefault() -> Browser? {
        NSWorkspace.shared.urlForApplication(toOpen: Self.httpProbe).flatMap(Browser.init(url:))
    }

    /// The application currently handling `https` URLs. Normally identical to `currentDefault()`.
    func currentHTTPSDefault() -> Browser? {
        NSWorkspace.shared.urlForApplication(toOpen: Self.httpsProbe).flatMap(Browser.init(url:))
    }

    /// Makes `browser` the default handler for `http` and `https`.
    ///
    /// macOS shows its own confirmation dialogue for the `http` change and normally updates `https`
    /// at the same time. If it did not, `https` is set explicitly (which may prompt again).
    /// The completion handler is always invoked on the main thread.
    func setDefault(_ browser: Browser, completion: @escaping (SetDefaultOutcome) -> Void) {
        // Already the http default (e.g. repairing a split state): go straight to https.
        if currentDefault() == browser {
            ensureHTTPS(browser, completion: completion)
            return
        }

        NSWorkspace.shared.setDefaultApplication(at: browser.url, toOpenURLsWithScheme: "http") { error in
            DispatchQueue.main.async { [self] in
                if let error {
                    completion(isUserCancellation(error) ? .cancelled : .failed(error))
                    return
                }
                // Some macOS releases report success even when the user keeps the old browser.
                guard currentDefault() == browser else {
                    completion(.cancelled)
                    return
                }
                ensureHTTPS(browser, completion: completion)
            }
        }
    }

    private func ensureHTTPS(_ browser: Browser, completion: @escaping (SetDefaultOutcome) -> Void) {
        if currentHTTPSDefault() == browser {
            completion(.changed)
            return
        }
        NSWorkspace.shared.setDefaultApplication(at: browser.url, toOpenURLsWithScheme: "https") { error in
            DispatchQueue.main.async { [self] in
                // Judge by the actual state, not just the reported error.
                if currentHTTPSDefault() == browser {
                    completion(.changed)
                } else {
                    completion(.partiallyChanged(error))
                }
            }
        }
    }

    /// True when the error means the user declined the system confirmation dialogue.
    func isUserCancellation(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError { return true }
        if nsError.domain == NSOSStatusErrorDomain && nsError.code == -128 { return true } // userCanceledErr
        return false
    }
}
