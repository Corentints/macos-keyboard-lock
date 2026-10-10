import Foundation

final class AppSettings {
    private enum Key {
        static let menuBarMode = "showMenuBarIcon"
    }

    private let defaults = UserDefaults.standard

    /// `true`: menu bar widget (popover). `false`: regular app with a window.
    var isMenuBarModeEnabled: Bool {
        get { defaults.bool(forKey: Key.menuBarMode) }
        set { defaults.set(newValue, forKey: Key.menuBarMode) }
    }
}
