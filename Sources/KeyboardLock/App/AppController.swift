import AppKit

/// Wires the lock session, the panel UI and whichever presenter (window or menu bar popover) is active.
final class AppController: LockPanelDelegate {
    private let settings = AppSettings()
    private let session = LockSession()
    private let panel = LockPanelView()
    private var presenter: PanelPresenter

    init() {
        panel.isMenuBarMode = settings.isMenuBarModeEnabled
        presenter = Self.makePresenter(menuBarMode: settings.isMenuBarModeEnabled, panel: panel)

        panel.actionDelegate = self
        session.onLockChange = { [weak self] isLocked in self?.sessionDidChange(isLocked: isLocked) }
        session.onTick = { [weak self] remainingSeconds in self?.panel.updateRemaining(remainingSeconds) }
    }

    var quitsWhenLastWindowClosed: Bool { presenter.quitsWhenLastWindowClosed }

    func start() {
        _ = KeyboardBlocker.isAccessibilityGranted(prompting: true)
        panel.show(.unlocked)
        presenter.present()
    }

    func reopen() {
        presenter.present()
    }

    func shutdown() {
        session.shutdown()
    }

    // MARK: LockPanelDelegate

    func lockPanel(_ panel: LockPanelView, didRequestLockFor duration: LockDuration) {
        do {
            try session.lock(for: duration)
        } catch {
            NSApp.activate(ignoringOtherApps: true)
            NSAlert(error: error).runModal()
        }
    }

    func lockPanelDidRequestUnlock(_ panel: LockPanelView) {
        session.unlock()
    }

    func lockPanel(_ panel: LockPanelView, didChangeMenuBarMode isEnabled: Bool) {
        settings.isMenuBarModeEnabled = isEnabled
        // Deferred: the checkbox that triggered this is about to be rebuilt.
        DispatchQueue.main.async { [self] in
            presenter.dismiss()
            panel.isMenuBarMode = isEnabled
            presenter = Self.makePresenter(menuBarMode: isEnabled, panel: panel)
            panel.show(.unlocked)
            presenter.present()
        }
    }

    // MARK: Private

    private static func makePresenter(menuBarMode: Bool, panel: LockPanelView) -> PanelPresenter {
        menuBarMode ? MenuBarPresenter(panel: panel) : WindowPresenter(panel: panel)
    }

    private func sessionDidChange(isLocked: Bool) {
        presenter.setLocked(isLocked)
        // The keyboard is already (un)blocked; the panel catches up once the padlock animation ends.
        panel.animatePadlock(locked: isLocked) { [weak self] in self?.showCurrentState() }
    }

    private func showCurrentState() {
        panel.show(session.isLocked ? .locked(remainingSeconds: session.remainingSeconds) : .unlocked)
    }
}
