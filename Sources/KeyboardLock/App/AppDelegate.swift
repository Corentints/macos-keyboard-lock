import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    // Lazy: AppKit objects (windows, status items) must not be created before the app is running.
    private lazy var controller = AppController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        MainMenu.install()
        controller.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.shutdown()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        controller.quitsWhenLastWindowClosed
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        controller.reopen()
        return true
    }
}
