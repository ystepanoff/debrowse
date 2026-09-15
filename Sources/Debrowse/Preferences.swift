import Foundation

enum Preferences {
    private static let showBrowserIconKey = "showBrowserIconInMenuBar"

    /// Show the current default browser's icon in the menu bar instead of a generic globe.
    static var showBrowserIcon: Bool {
        get { UserDefaults.standard.object(forKey: showBrowserIconKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: showBrowserIconKey) }
    }
}
