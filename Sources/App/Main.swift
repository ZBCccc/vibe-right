import AppKit
import FinderSync
import Foundation

@main
struct VibeRightApplication {
    private static var retainedDelegate: AppDelegate?

    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        retainedDelegate = delegate
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: MainWindowController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        ConfigStore.shared.reload()
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(configChanged),
            name: Notification.Name("com.vibecoding.VibeRight.configChanged"),
            object: nil
        )
        updateStatusItemVisibility()
        showSettings()
    }

    func applicationWillTerminate(_ notification: Notification) {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        showSettings()
    }

    @objc private func configChanged() {
        ConfigStore.shared.reload()
        updateStatusItemVisibility()
    }

    private func updateStatusItemVisibility() {
        guard ConfigStore.shared.config.showMenuBarIcon else {
            if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
            statusItem = nil
            return
        }
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "cursorarrow.click.2", accessibilityDescription: "灵犀右键")
        item.button?.toolTip = "灵犀右键"

        let menu = NSMenu()
        let settings = NSMenuItem(title: "打开设置", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        let extensionSettings = NSMenuItem(title: "管理 Finder 扩展", action: #selector(showExtensionSettings), keyEquivalent: "")
        extensionSettings.target = self
        menu.addItem(extensionSettings)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出灵犀右键", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
        item.menu = menu
        statusItem = item
    }

    @objc private func showSettings() {
        if windowController == nil { windowController = MainWindowController() }
        windowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showExtensionSettings() {
        FIFinderSyncController.showExtensionManagementInterface()
    }
}
