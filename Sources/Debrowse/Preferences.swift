import Foundation

enum Preferences {
    private static let showBrowserIconKey = "showBrowserIconInMenuBar"
    private static let skipConfirmationKey = "skipConfirmationDialogue"

    /// Show the current default browser's icon in the menu bar instead of a generic globe.
    static var showBrowserIcon: Bool {
        get { UserDefaults.standard.object(forKey: showBrowserIconKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: showBrowserIconKey) }
    }

    /// Press "Use <browser>" on the system's confirmation dialogue automatically.
    /// Only takes effect once the Accessibility permission has been granted.
    static var skipConfirmation: Bool {
        get { UserDefaults.standard.bool(forKey: skipConfirmationKey) }
        set { UserDefaults.standard.set(newValue, forKey: skipConfirmationKey) }
    }
}
