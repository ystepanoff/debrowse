import Foundation
import ServiceManagement

/// Wraps SMAppService so the app can register itself as a login item.
enum LoginItem {
    enum State {
        /// Not running from a real `.app` bundle; registration is impossible.
        case unavailable
        case disabled
        case enabled
        /// Registered, but the user still has to approve it in System Settings › Login Items.
        case requiresApproval
    }

    static var isAvailable: Bool {
        Bundle.main.bundleIdentifier != nil && Bundle.main.bundleURL.pathExtension == "app"
    }

    static var state: State {
        guard isAvailable else { return .unavailable }
        switch SMAppService.mainApp.status {
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        case .notRegistered, .notFound: return .disabled
        @unknown default: return .disabled
        }
    }

    /// Flips registration. When approval is pending, opens the Login Items pane instead so the
    /// user can finish there.
    static func toggle() throws {
        switch state {
        case .unavailable:
            return
        case .enabled:
            try SMAppService.mainApp.unregister()
        case .disabled:
            try SMAppService.mainApp.register()
        case .requiresApproval:
            SMAppService.openSystemSettingsLoginItems()
        }
    }
}
