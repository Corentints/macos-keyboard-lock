import Foundation

enum LockError: LocalizedError {
    case accessibilityDenied
    case eventTapUnavailable

    var errorDescription: String? {
        switch self {
        case .accessibilityDenied: "Permission required"
        case .eventTapUnavailable: "Unable to lock the keyboard"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .accessibilityDenied:
            "Enable KeyboardLock in System Settings › Privacy & Security › Accessibility, then relaunch the app."
        case .eventTapUnavailable:
            "Also check Input Monitoring in Privacy & Security."
        }
    }
}
