import AppKit

enum MainMenu {
    /// Minimal main menu, only there so that Cmd+Q works.
    static func install() {
        let quitItem = NSMenuItem(title: "Quit KeyboardLock",
                                  action: #selector(NSApplication.terminate(_:)),
                                  keyEquivalent: "q")
        let appMenu = NSMenu()
        appMenu.addItem(quitItem)

        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu

        let mainMenu = NSMenu()
        mainMenu.addItem(appMenuItem)
        NSApp.mainMenu = mainMenu
    }
}
