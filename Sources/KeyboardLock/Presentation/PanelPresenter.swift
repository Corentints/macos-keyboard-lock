import AppKit

/// Hosts the lock panel, either in a regular window or in a menu bar popover.
protocol PanelPresenter: AnyObject {
    var quitsWhenLastWindowClosed: Bool { get }

    func present()
    func dismiss()
    /// While locked, the panel must stay reachable: it cannot be closed or dismissed.
    func setLocked(_ isLocked: Bool)
}
