import AppKit
import FinderSync
import Foundation

@objc(FinderSync)
final class FinderSync: FIFinderSync {
    private let controller = FIFinderSyncController.default()
    private let store = ConfigStore.shared
    private var payloadByTag: [Int: String] = [:]
    private var nextActionTag = 10_000

    override init() {
        super.init()
        controller.directoryURLs = [URL(fileURLWithPath: "/", isDirectory: true)]
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(configChanged),
            name: Notification.Name("com.vibecoding.VibeRight.configChanged"),
            object: nil
        )
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    @objc private func configChanged() {
        store.reload()
    }

    override var toolbarItemName: String { "灵犀右键" }
    override var toolbarItemToolTip: String { "打开灵犀右键菜单" }
    override var toolbarItemImage: NSImage {
        NSImage(systemSymbolName: "cursorarrow.click.2", accessibilityDescription: "灵犀右键")
            ?? NSImage(size: NSSize(width: 18, height: 18))
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        store.reload()
        let menu = NSMenu(title: "灵犀右键")
        let hasSelection = !(controller.selectedItemURLs()?.isEmpty ?? true)

        if menuKind == .contextualMenuForContainer || menuKind == .toolbarItemMenu || !hasSelection {
            menu.addItem(newFileMenu())
            menu.addItem(commonDirectoryMenu())
            menu.addItem(.separator())
            addDirectoryTools(to: menu)
        } else {
            menu.addItem(newFileMenu())
            menu.addItem(transferMenu(title: "移动文件到…", action: "move"))
            menu.addItem(transferMenu(title: "复制文件到…", action: "copy"))
            menu.addItem(.separator())
            addSelectionTools(to: menu)
        }

        menu.addItem(.separator())
        menu.addItem(actionItem(title: "打开灵犀右键设置", symbol: "gearshape", payload: "settings"))
        return menu
    }

    private func newFileMenu() -> NSMenuItem {
        let root = NSMenuItem(title: "新建文件", action: nil, keyEquivalent: "")
        root.image = image("doc.badge.plus")
        let submenu = NSMenu(title: "新建文件")
        for template in store.config.templates where template.enabled {
            submenu.addItem(actionItem(
                title: template.name,
                symbol: template.isDirectory ? "folder.badge.plus" : "doc",
                payload: "new|\(template.id)"
            ))
        }
        root.submenu = submenu
        return root
    }

    private func transferMenu(title: String, action: String) -> NSMenuItem {
        let root = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        root.image = image(action == "copy" ? "doc.on.doc" : "folder")
        let submenu = NSMenu(title: title)
        for destination in store.config.destinations where destination.enabled {
            submenu.addItem(actionItem(
                title: destination.name,
                symbol: "folder",
                payload: "\(action)|\(destination.id)"
            ))
        }
        root.submenu = submenu
        return root
    }

    private func commonDirectoryMenu() -> NSMenuItem {
        let root = NSMenuItem(title: "常用目录", action: nil, keyEquivalent: "")
        root.image = image("heart")
        let submenu = NSMenu(title: "常用目录")
        for destination in store.config.destinations where destination.enabled {
            submenu.addItem(actionItem(title: destination.name, symbol: "folder", payload: "open|\(destination.id)"))
        }
        root.submenu = submenu
        return root
    }

    private func addDirectoryTools(to menu: NSMenu) {
        let directoryTools: [ToolActionID] = [
            .copyPath, .openTerminal, .openWarp, .openITerm2, .openVSCode, .openCursor, .openGoLand
        ]
        for tool in directoryTools where store.config.enabledTools.contains(tool) {
            menu.addItem(toolItem(tool))
        }
    }

    private func addSelectionTools(to menu: NSMenu) {
        for tool in ToolActionID.allCases where store.config.enabledTools.contains(tool) {
            if tool == .fileInfo {
                let item = NSMenuItem(title: tool.title, action: nil, keyEquivalent: "")
                item.image = image(tool.symbolName)
                let submenu = NSMenu(title: tool.title)
                submenu.addItem(actionItem(title: "MD5", symbol: "number", payload: "checksum|md5"))
                submenu.addItem(actionItem(title: "SHA-256", symbol: "number", payload: "checksum|sha256"))
                item.submenu = submenu
                menu.addItem(item)
            } else {
                menu.addItem(toolItem(tool))
            }
        }
    }

    private func toolItem(_ tool: ToolActionID) -> NSMenuItem {
        actionItem(title: tool.title, symbol: tool.symbolName, payload: "tool|\(tool.rawValue)")
    }

    private func actionItem(title: String, symbol: String, payload: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(handleAction(_:)), keyEquivalent: "")
        item.target = self
        nextActionTag += 1
        item.tag = nextActionTag
        payloadByTag[nextActionTag] = payload
        item.image = image(symbol)
        return item
    }

    private func image(_ symbol: String) -> NSImage? {
        guard store.config.showIcons else { return nil }
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        image?.size = NSSize(width: 16, height: 16)
        return image
    }

    @objc private func handleAction(_ sender: NSMenuItem) {
        guard let payload = payloadByTag[sender.tag] else { return }
        do {
            try execute(payload)
            if store.config.playSound { NSSound(named: "Glass")?.play() }
        } catch {
            showAlert(title: "操作失败", message: error.localizedDescription)
        }
    }

    private func execute(_ payload: String) throws {
        let parts = payload.split(separator: "|", maxSplits: 1).map(String.init)
        let action = parts[0]
        let argument = parts.count > 1 ? parts[1] : ""

        switch action {
        case "settings":
            openSettings()
        case "new":
            guard let template = store.config.templates.first(where: { $0.id == argument }) else { return }
            let url = try FileOperations.create(template: template, in: try targetDirectory())
            if store.config.autoOpenNewFile { NSWorkspace.shared.open(url) }
        case "copy", "move":
            guard let destination = store.config.destinations.first(where: { $0.id == argument }) else { return }
            let urls = selectedURLs()
            if action == "copy" { try FileOperations.copy(urls, to: destination.expandedURL) }
            else { try FileOperations.move(urls, to: destination.expandedURL) }
        case "open":
            guard let destination = store.config.destinations.first(where: { $0.id == argument }) else { return }
            NSWorkspace.shared.open(destination.expandedURL)
        case "checksum":
            let lines = try selectedURLs().map { "\($0.lastPathComponent): \(try FileOperations.checksum(of: $0, algorithm: argument))" }
            copyToPasteboard(lines.joined(separator: "\n"))
        case "tool":
            guard let tool = ToolActionID(rawValue: argument) else { return }
            try executeTool(tool)
        default:
            return
        }
    }

    private func executeTool(_ tool: ToolActionID) throws {
        let urls = selectedURLs()
        switch tool {
        case .copyName:
            copyToPasteboard(urls.map(\.lastPathComponent).joined(separator: "\n"))
        case .copyPath:
            let values = urls.isEmpty ? [try targetDirectory()] : urls
            copyToPasteboard(values.map(\.path).joined(separator: "\n"))
        case .createFolderFromName:
            try FileOperations.createFoldersFromNames(for: urls)
        case .toggleHidden:
            try FileOperations.toggleHidden(urls)
        case .openTerminal:
            try open(urls: directoryURLs(from: urls), appName: "Terminal", bundleIdentifiers: ["com.apple.Terminal"])
        case .openWarp:
            try open(urls: directoryURLs(from: urls), appName: "Warp", bundleIdentifiers: ["dev.warp.Warp-Stable"])
        case .openITerm2:
            try open(urls: directoryURLs(from: urls), appName: "iTerm2", bundleIdentifiers: ["com.googlecode.iterm2"])
        case .openVSCode:
            try open(urls: directoryURLs(from: urls), appName: "Visual Studio Code", bundleIdentifiers: ["com.microsoft.VSCode"])
        case .openCursor:
            try open(urls: directoryURLs(from: urls), appName: "Cursor", bundleIdentifiers: ["com.todesktop.230313mzl4w4u92"])
        case .openGoLand:
            try open(urls: directoryURLs(from: urls), appName: "GoLand", bundleIdentifiers: ["com.jetbrains.goland"])
        case .convertPNG:
            try FileOperations.convertImages(urls, to: .png)
        case .convertJPEG:
            try FileOperations.convertImages(urls, to: .jpeg)
        case .fileInfo:
            break
        }
    }

    private func targetDirectory() throws -> URL {
        if let target = controller.targetedURL() {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: target.path, isDirectory: &isDirectory), isDirectory.boolValue {
                return target
            }
            return target.deletingLastPathComponent()
        }
        if let selected = controller.selectedItemURLs()?.first {
            return selected.deletingLastPathComponent()
        }
        throw FileOperationError.noTargetDirectory
    }

    private func selectedURLs() -> [URL] {
        controller.selectedItemURLs() ?? []
    }

    private func directoryURLs(from urls: [URL]) -> [URL] {
        if urls.isEmpty, let target = try? targetDirectory() { return [target] }
        return urls.map { url in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
                ? url
                : url.deletingLastPathComponent()
        }
    }

    private func open(urls: [URL], appName: String, bundleIdentifiers: [String]) throws {
        let workspace = NSWorkspace.shared
        guard let appURL = bundleIdentifiers.compactMap({ workspace.urlForApplication(withBundleIdentifier: $0) }).first else {
            throw FileOperationError.applicationNotFound(appName)
        }
        workspace.open(urls, withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
    }

    private func openSettings() {
        if let url = URL(string: "viberight://settings") { NSWorkspace.shared.open(url) }
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }
}
