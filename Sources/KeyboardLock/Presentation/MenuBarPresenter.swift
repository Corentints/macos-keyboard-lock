import AppKit

/// Widget mode: a menu bar icon that opens the panel in a floating glass panel. No Dock icon, no window.
/// A custom panel is used instead of NSPopover because NSPopover shifts vertically when its state changes.
final class MenuBarPresenter: NSObject, PanelPresenter {
    private enum Layout {
        static let panelTopInset: CGFloat = 28
        static let cornerRadius: CGFloat = 26
        static let gapBelowMenuBar: CGFloat = 6
        static let screenMargin: CGFloat = 8
    }

    private let panel: LockPanelView
    private let window: NSPanel
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var outsideClickMonitor: Any?
    private var isLocked = false

    let quitsWhenLastWindowClosed = false

    init(panel: LockPanelView) {
        self.panel = panel
        window = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()

        NSApp.setActivationPolicy(.accessory)
        panel.edgeInsets.top = Layout.panelTopInset
        panel.fixHeightToTallestMode()

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.contentView = GlassBackground.wrapping(panel, cornerRadius: Layout.cornerRadius)
        window.setContentSize(panel.fittingSize)

        statusItem.button?.target = self
        statusItem.button?.action = #selector(toggle)
        updateStatusIcon()
    }

    func present() {
        showWhenStatusItemIsPlaced(retries: 20)
    }

    func dismiss() {
        hide()
        panel.removeFromSuperview()
        window.contentView = nil
        NSStatusBar.system.removeStatusItem(statusItem)
    }

    func setLocked(_ isLocked: Bool) {
        self.isLocked = isLocked
        window.level = isLocked ? .screenSaver : .statusBar
        updateStatusIcon()
    }

    // MARK: Showing / hiding

    @objc private func toggle() {
        if window.isVisible {
            if !isLocked { hide() }
        } else {
            present()
        }
    }

    /// A fresh status item has no position yet; anchoring the panel too early puts it at the screen's corner.
    private func showWhenStatusItemIsPlaced(retries: Int) {
        guard !window.isVisible, let buttonWindow = statusItem.button?.window else { return }

        guard buttonWindow.frame.origin.y > 0 || retries == 0 else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [self] in
                showWhenStatusItemIsPlaced(retries: retries - 1)
            }
            return
        }
        window.setFrameOrigin(origin(below: buttonWindow))
        window.orderFrontRegardless()
        startMonitoringOutsideClicks()
    }

    /// Centered under the status item, below the menu bar, kept inside the screen.
    private func origin(below buttonWindow: NSWindow) -> NSPoint {
        let size = window.frame.size
        let button = buttonWindow.frame
        var x = button.midX - size.width / 2
        if let screen = buttonWindow.screen {
            x = min(max(x, screen.frame.minX + Layout.screenMargin), screen.frame.maxX - size.width - Layout.screenMargin)
        }
        return NSPoint(x: x, y: button.minY - size.height - Layout.gapBelowMenuBar)
    }

    private func hide() {
        window.orderOut(nil)
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        outsideClickMonitor = nil
    }

    private func startMonitoringOutsideClicks() {
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, !self.isLocked else { return }
            self.hide()
        }
    }

    private func updateStatusIcon() {
        let symbol = isLocked ? "lock.fill" : "lock.open.fill"
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Keyboard lock")
    }
}
