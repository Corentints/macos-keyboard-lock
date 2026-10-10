import AppKit

/// Simple app mode: Dock icon and a Liquid Glass window.
final class WindowPresenter: NSObject, PanelPresenter, NSWindowDelegate {
    private static let panelTopInset: CGFloat = 44 // room for the transparent title bar

    private let panel: LockPanelView
    private let window: NSWindow
    private var isLocked = false

    let quitsWhenLastWindowClosed = true

    init(panel: LockPanelView) {
        self.panel = panel
        window = NSWindow(contentRect: .zero,
                          styleMask: [.titled, .closable, .fullSizeContentView],
                          backing: .buffered,
                          defer: false)
        super.init()

        NSApp.setActivationPolicy(.regular)
        panel.edgeInsets.top = Self.panelTopInset
        panel.fixHeightToTallestMode()

        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = GlassBackground.wrapping(panel)
    }

    func present() {
        if !window.isVisible {
            resizeToFitPanel()
            window.center()
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func dismiss() {
        window.orderOut(nil)
        window.contentView = nil
    }

    func setLocked(_ isLocked: Bool) {
        self.isLocked = isLocked
        window.level = isLocked ? .screenSaver : .normal
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        !isLocked
    }

    /// Resizes while keeping the window's top edge in place.
    private func resizeToFitPanel() {
        let target = window.frameRect(forContentRect: NSRect(origin: .zero, size: panel.fittingSize))
        var frame = window.frame
        frame.origin.y += frame.height - target.height
        frame.size = target.size
        window.setFrame(frame, display: true)
    }
}
