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
        store.reload()
        updateDirectoryURLs()
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(configChanged),
            name: Notification.Name("com.vibecoding.VibeRight.configChanged"),
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(volumesChanged),
            name: NSWorkspace.didMountNotification,
            object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(volumesChanged),
            name: NSWorkspace.didUnmountNotification,
            object: nil
        )
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    @objc private func configChanged() {
        store.reload()
        updateDirectoryURLs()
    }

    @objc private func volumesChanged() {
        updateDirectoryURLs()
    }

    override var toolbarItemName: String { L10n.text("灵犀右键") }
    override var toolbarItemToolTip: String { L10n.text("打开灵犀右键菜单") }
    override var toolbarItemImage: NSImage {
        NSImage(systemSymbolName: "cursorarrow.click.2", accessibilityDescription: L10n.text("灵犀右键"))
            ?? NSImage(size: NSSize(width: 18, height: 18))
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        store.reload()
        updateDirectoryURLs()
        let selectionURLs = controller.selectedItemURLs() ?? []
        let contextURLs = FinderScope.contextURLs(selected: selectionURLs, targeted: controller.targetedURL())
        guard !contextURLs.isEmpty else { return nil }
        if !store.config.includeExternalVolumes, contextURLs.contains(where: FinderScope.isExternalVolume) {
            return nil
        }
        let menu = NSMenu(title: L10n.text("灵犀右键"))
        let hasSelection = !selectionURLs.isEmpty

        if menuKind == .contextualMenuForContainer || menuKind == .toolbarItemMenu || !hasSelection {
            addNewFileItems(to: menu)
            if store.config.favoritesEnabled, store.config.favorites.contains(where: \.enabled) {
                menu.addItem(commonDirectoryMenu())
            }
            addPendingCutActions(to: menu)
            menu.addItem(.separator())
            addDirectoryTools(to: menu)
        } else {
            addNewFileItems(to: menu)
            if store.config.moveEnabled {
                menu.addItem(transferMenu(title: "移动文件到…", action: "move"))
            }
            if store.config.copyEnabled {
                menu.addItem(transferMenu(title: "复制文件到…", action: "copy"))
            }
            if selectedURLs().count == 1, selectedURLs().first.map(isDirectory) == true {
                addPendingCutActions(to: menu)
            }
            menu.addItem(.separator())
            addSelectionTools(to: menu)
        }

        menu.addItem(.separator())
        menu.addItem(actionItem(title: "打开灵犀右键设置", symbol: "gearshape", payload: "settings"))
        return menu
    }

    private func addNewFileItems(to menu: NSMenu) {
        let templates = store.config.templates.filter(\.enabled)
        for template in templates where template.showInMainMenu {
            let localizedName = L10n.text(template.name)
            let title = template.name.hasPrefix("新建")
                ? localizedName
                : L10n.format("新建 %@", localizedName)
            menu.addItem(actionItem(
                title: title,
                symbol: template.isDirectory ? "folder.badge.plus" : "doc.badge.plus",
                payload: "new|\(template.id)"
            ))
        }

        let submenuTemplates = templates.filter { !$0.showInMainMenu }
        guard !submenuTemplates.isEmpty else { return }
        menu.addItem(newFileMenu(templates: submenuTemplates))
    }

    private func newFileMenu(templates: [FileTemplate]) -> NSMenuItem {
        let root = NSMenuItem(title: L10n.text("新建文件"), action: nil, keyEquivalent: "")
        root.image = image("doc.badge.plus")
        let submenu = NSMenu(title: L10n.text("新建文件"))
        for template in templates {
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
        let localizedTitle = L10n.text(title)
        let root = NSMenuItem(title: localizedTitle, action: nil, keyEquivalent: "")
        root.image = image(action == "copy" ? "doc.on.doc" : "folder")
        let submenu = NSMenu(title: localizedTitle)
        for destination in store.config.destinations where destination.enabled {
            submenu.addItem(actionItem(
                title: destination.name,
                symbol: "folder",
                payload: "\(action)|\(destination.id)"
            ))
        }
        if !submenu.items.isEmpty { submenu.addItem(.separator()) }
        submenu.addItem(actionItem(
            title: "自定义路径…",
            symbol: "folder.badge.plus",
            payload: "\(action)Custom"
        ))
        root.submenu = submenu
        return root
    }

    private func commonDirectoryMenu() -> NSMenuItem {
        let root = NSMenuItem(title: L10n.text("常用目录"), action: nil, keyEquivalent: "")
        root.image = image("heart")
        let submenu = NSMenu(title: L10n.text("常用目录"))
        for destination in store.config.favorites where destination.enabled {
            submenu.addItem(actionItem(title: destination.name, symbol: "folder", payload: "open|\(destination.id)"))
        }
        root.submenu = submenu
        return root
    }

    private func addPendingCutActions(to menu: NSMenu) {
        let pending = pendingCutURLs()
        guard !pending.isEmpty else { return }
        menu.addItem(.separator())
        menu.addItem(actionItem(
            title: "粘贴剪切项目到这里",
            symbol: "arrow.right.doc.on.clipboard",
            payload: "pasteCut"
        ))
        menu.addItem(actionItem(
            title: "取消剪切",
            symbol: "xmark.circle",
            payload: "cancelCut"
        ))
    }

    private func addDirectoryTools(to menu: NSMenu) {
        let directoryTools: [ToolActionID] = [
            .copyPath,
            .unhideAll,
            .hideAll
        ]
        addTools(
            directoryTools,
            to: menu,
            merged: store.config.mergeFileActions,
            title: "文件（夹）工具",
            symbol: "wrench.and.screwdriver"
        )
        addApplicationTools(to: menu)
    }

    private func addSelectionTools(to menu: NSMenu) {
        let urls = selectedURLs()
        let allDirectories = !urls.isEmpty && urls.allSatisfy(isDirectory)
        let allImages = !urls.isEmpty && urls.allSatisfy(isImage)
        let allRegularFiles = !urls.isEmpty && urls.allSatisfy { !isDirectory($0) }

        addFileIconMenu(to: menu)

        var tools: [ToolActionID] = [
            .fileInfo,
            .createDesktopShortcut,
            .shareAirDrop,
            .copyName,
            .createFolderFromName,
            .cut
        ]
        if allDirectories { tools.append(.dissolveFolder) }
        if allImages { tools.append(.setWallpaper) }
        tools.append(.copyPath)
        if urls.count == 1, allDirectories { tools.append(.addToFavorites) }
        tools.append(contentsOf: [
            .permanentDelete,
            .grantWritePermission,
            .unhideSelected,
            .hideSelected
        ])
        if allRegularFiles { tools.append(.toggleFileExtension) }
        tools.append(.repairFilename)
        tools.append(.generateQRCode)
        tools.append(.compress7Z)
        tools.append(.compressZIP)
        if urls.allSatisfy({ ["zip", "7z"].contains($0.pathExtension.lowercased()) }) {
            tools.append(.extractArchive)
        }
        addTools(
            tools,
            to: menu,
            merged: store.config.mergeFileActions,
            title: "文件（夹）工具",
            symbol: "wrench.and.screwdriver"
        )
        if allImages {
            let imageTools: [ToolActionID] = [
                .convertWebP,
                .convertHEIC,
                .convertJPEG,
                .convertPNG,
                .convertICNS,
                .makeMacIconSet,
                .makeIOSIconSet
            ]
            addTools(
                imageTools,
                to: menu,
                merged: store.config.mergeImageActions,
                title: "图片转换",
                symbol: "photo.badge.arrow.down"
            )
        }
        addApplicationTools(to: menu)
    }

    private func addTools(
        _ tools: [ToolActionID],
        to menu: NSMenu,
        merged: Bool,
        title: String,
        symbol: String
    ) {
        let enabled = store.config.orderedTools(from: tools).filter { store.config.enabledTools.contains($0) }
        guard !enabled.isEmpty else { return }
        guard merged else {
            for tool in enabled { addTool(tool, to: menu) }
            return
        }
        let localizedTitle = L10n.text(title)
        let root = NSMenuItem(title: localizedTitle, action: nil, keyEquivalent: "")
        root.image = image(symbol)
        let submenu = NSMenu(title: localizedTitle)
        for tool in enabled { addTool(tool, to: submenu) }
        root.submenu = submenu
        menu.addItem(root)
    }

    private func addFileIconMenu(to menu: NSMenu) {
        let presets = FileIconPreset.allCases.filter { store.config.enabledIconPresets.contains($0) }
        let customIcons = store.config.customIcons.filter(\.enabled)
        guard !presets.isEmpty || !customIcons.isEmpty else { return }

        let root = NSMenuItem(title: L10n.text("文件（夹）图标"), action: nil, keyEquivalent: "")
        root.image = image("photo.stack")
        let submenu = NSMenu(title: root.title)
        submenu.addItem(actionItem(title: "删除自定义图标", symbol: "arrow.uturn.backward", payload: "icon|remove"))
        submenu.addItem(.separator())
        for preset in presets {
            submenu.addItem(actionItem(
                title: preset.title,
                symbol: preset.symbolName,
                payload: "icon|\(preset.rawValue)"
            ))
        }
        if !presets.isEmpty, !customIcons.isEmpty { submenu.addItem(.separator()) }
        for customIcon in customIcons {
            submenu.addItem(actionItem(
                title: customIcon.name,
                symbol: "photo",
                payload: "customIcon|\(customIcon.id)"
            ))
        }
        root.submenu = submenu
        menu.addItem(root)
    }

    private func addApplicationTools(to menu: NSMenu) {
        let applications = store.config.applications.filter(\.enabled)
        guard !applications.isEmpty else { return }
        let target: NSMenu
        if store.config.mergeApplicationActions {
            let root = NSMenuItem(title: L10n.text("进入应用"), action: nil, keyEquivalent: "")
            root.image = image("app.badge")
            let submenu = NSMenu(title: root.title)
            root.submenu = submenu
            menu.addItem(root)
            target = submenu
        } else {
            target = menu
        }
        for application in applications {
            target.addItem(actionItem(
                title: L10n.format("进入 %@", L10n.text(application.name)),
                symbol: application.symbolName,
                payload: "application|\(application.id)"
            ))
        }
    }

    private func addTool(_ tool: ToolActionID, to menu: NSMenu) {
        guard tool == .fileInfo else {
            menu.addItem(toolItem(tool))
            return
        }
        let title = store.config.title(for: tool)
        let item = NSMenuItem(title: L10n.text(title), action: nil, keyEquivalent: "")
        item.image = image(tool.symbolName)
        let submenu = NSMenu(title: L10n.text(title))
        submenu.addItem(actionItem(title: "MD5", symbol: "number", payload: "checksum|md5"))
        submenu.addItem(actionItem(title: "SHA-1", symbol: "number", payload: "checksum|sha1"))
        submenu.addItem(actionItem(title: "SHA-256", symbol: "number", payload: "checksum|sha256"))
        submenu.addItem(actionItem(title: "SHA-512", symbol: "number", payload: "checksum|sha512"))
        item.submenu = submenu
        menu.addItem(item)
    }

    private func toolItem(_ tool: ToolActionID) -> NSMenuItem {
        actionItem(title: store.config.title(for: tool), symbol: tool.symbolName, payload: "tool|\(tool.rawValue)")
    }

    private func actionItem(title: String, symbol: String, payload: String) -> NSMenuItem {
        let item = NSMenuItem(title: L10n.text(title), action: #selector(handleAction(_:)), keyEquivalent: "")
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
            let performed = try execute(payload)
            if performed, store.config.playSound { NSSound(named: "Glass")?.play() }
        } catch {
            showAlert(title: L10n.text("操作失败"), message: error.localizedDescription)
        }
    }

    private func execute(_ payload: String) throws -> Bool {
        let parts = payload.split(separator: "|", maxSplits: 1).map(String.init)
        let action = parts[0]
        let argument = parts.count > 1 ? parts[1] : ""

        switch action {
        case "settings":
            openSettings()
            return true
        case "new":
            guard let template = store.config.templates.first(where: { $0.id == argument }) else { return false }
            let url = try FileOperations.create(template: template, in: try targetDirectory())
            if store.config.autoOpenNewFile { NSWorkspace.shared.open(url) }
            return true
        case "copy", "move":
            guard let destination = store.config.destinations.first(where: { $0.id == argument }) else { return false }
            let urls = selectedURLs()
            if action == "copy" { try FileOperations.copy(urls, to: destination.expandedURL) }
            else { try FileOperations.move(urls, to: destination.expandedURL) }
            return true
        case "copyCustom", "moveCustom":
            return try chooseDestinationAndTransfer(action: action == "copyCustom" ? "copy" : "move")
        case "open":
            guard let destination = store.config.favorites.first(where: { $0.id == argument }) else { return false }
            NSWorkspace.shared.open(destination.expandedURL)
            return true
        case "checksum":
            let lines = try selectedURLs().map { "\($0.lastPathComponent): \(try FileOperations.checksum(of: $0, algorithm: argument))" }
            copyToPasteboard(lines.joined(separator: "\n"))
            return true
        case "tool":
            guard let tool = ToolActionID(rawValue: argument) else { return false }
            return try executeTool(tool)
        case "application":
            guard let application = store.config.applications.first(where: { $0.id == argument }) else { return false }
            let directories = directoryURLs(from: selectedURLs())
            if application.id == "terminal" {
                try requestTerminalOpen(.terminal, mode: store.config.terminalOpenMode, directories: directories)
            } else if application.id == "iterm2" {
                try requestTerminalOpen(.iTerm2, mode: store.config.iTermOpenMode, directories: directories)
            } else {
                try open(
                    urls: directories,
                    appName: application.name,
                    bundleIdentifiers: application.bundleIdentifiers
                )
            }
            return true
        case "pasteCut":
            return try pastePendingCutItems()
        case "cancelCut":
            try clearPendingCut(restoreVisibility: true)
            return true
        case "icon":
            let urls = selectedURLs()
            if argument == "remove" {
                try FileOperations.removeCustomIcons(from: urls)
            } else if let preset = FileIconPreset(rawValue: argument) {
                try FileOperations.applyIconPreset(preset, to: urls)
            } else {
                return false
            }
            return true
        case "customIcon":
            guard let customIcon = store.config.customIcons.first(where: { $0.id == argument }) else { return false }
            try FileOperations.applyCustomIcon(at: URL(fileURLWithPath: customIcon.path), to: selectedURLs())
            return true
        default:
            return false
        }
    }

    private func executeTool(_ tool: ToolActionID) throws -> Bool {
        let urls = selectedURLs()
        switch tool {
        case .createDesktopShortcut:
            try FileOperations.createDesktopShortcuts(for: urls)
        case .shareAirDrop:
            guard let service = NSSharingService(named: .sendViaAirDrop) else {
                throw FileOperationError.processFailed(L10n.text("当前无法使用隔空投送"))
            }
            service.perform(withItems: urls)
        case .copyName:
            copyToPasteboard(urls.map(\.lastPathComponent).joined(separator: "\n"))
        case .copyPath:
            let values = urls.isEmpty ? [try targetDirectory()] : urls
            copyToPasteboard(values.map(\.path).joined(separator: "\n"))
        case .createFolderFromName:
            try FileOperations.createFoldersFromNames(for: urls)
        case .cut:
            try startCut(urls)
        case .dissolveFolder:
            try FileOperations.dissolveFolders(urls)
        case .setWallpaper:
            guard let imageURL = urls.first else { throw FileOperationError.emptySelection }
            guard NSImage(contentsOf: imageURL) != nil else { throw FileOperationError.unsupportedImage(imageURL) }
            for screen in NSScreen.screens {
                try NSWorkspace.shared.setDesktopImageURL(imageURL, for: screen, options: [:])
            }
        case .addToFavorites:
            guard let directory = urls.first, isDirectory(directory) else {
                throw FileOperationError.noTargetDirectory
            }
            try addToFavorites(directory)
        case .grantWritePermission:
            try FileOperations.grantOwnerWritePermission(to: urls)
        case .hideAll:
            try FileOperations.setHiddenForContents(true, in: try targetDirectory())
        case .unhideAll:
            try FileOperations.setHiddenForContents(false, in: try targetDirectory())
        case .hideSelected:
            try FileOperations.setHidden(true, for: urls)
        case .unhideSelected:
            try FileOperations.setHidden(false, for: urls)
        case .toggleFileExtension:
            try FileOperations.toggleHiddenExtension(for: urls)
        case .repairFilename:
            let repairs = try FileOperations.proposedFilenameRepairs(for: urls)
            guard !repairs.isEmpty else {
                throw FileOperationError.processFailed(L10n.text("未发现可高置信度修复的乱码文件名"))
            }
            let preview = repairs.prefix(8).map {
                "\($0.source.lastPathComponent)  →  \($0.target.lastPathComponent)"
            }.joined(separator: "\n")
            let remaining = repairs.count > 8 ? "\n" + L10n.format("…以及另外 %d 项", repairs.count - 8) : ""
            let alert = NSAlert()
            alert.messageText = L10n.text("确认修复乱码文件名？")
            alert.informativeText = preview + remaining
            alert.alertStyle = .informational
            alert.addButton(withTitle: L10n.text("修复"))
            alert.addButton(withTitle: L10n.text("取消"))
            guard alert.runModal() == .alertFirstButtonReturn else { return false }
            try FileOperations.applyFilenameRepairs(repairs)
        case .generateQRCode:
            guard let first = urls.first else { throw FileOperationError.emptySelection }
            _ = try FileOperations.createQRCode(
                from: urls.map(\.path).joined(separator: "\n"),
                in: first.deletingLastPathComponent()
            )
        case .permanentDelete:
            if store.config.confirmPermanentDelete {
                let alert = NSAlert()
                alert.messageText = L10n.text("彻底删除所选项目？")
                alert.informativeText = L10n.text("此操作不会移入废纸篓，删除后无法恢复。")
                alert.alertStyle = .critical
                alert.addButton(withTitle: L10n.text("彻底删除"))
                alert.addButton(withTitle: L10n.text("取消"))
                guard alert.runModal() == .alertFirstButtonReturn else { return false }
            }
            try FileOperations.deletePermanently(urls)
        case .compress7Z:
            try FileOperations.create7Z(from: urls)
        case .compressZIP:
            try FileOperations.createZIP(from: urls)
        case .extractArchive:
            try FileOperations.extractArchives(urls)
        case .toggleHidden:
            try FileOperations.toggleHidden(urls)
        case .openTerminal:
            try requestTerminalOpen(.terminal, mode: store.config.terminalOpenMode, directories: directoryURLs(from: urls))
        case .openWarp:
            try open(urls: directoryURLs(from: urls), appName: "Warp", bundleIdentifiers: ["dev.warp.Warp-Stable"])
        case .openITerm2:
            try requestTerminalOpen(.iTerm2, mode: store.config.iTermOpenMode, directories: directoryURLs(from: urls))
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
        case .convertWebP:
            try FileOperations.convertImagesToWebP(urls)
        case .convertHEIC:
            try FileOperations.convertImagesToHEIC(urls)
        case .convertICNS:
            try FileOperations.convertImagesToICNS(urls)
        case .makeMacIconSet:
            try FileOperations.createMacIconSets(urls)
        case .makeIOSIconSet:
            try FileOperations.createIOSIconSets(urls)
        case .fileInfo:
            return false
        }
        return true
    }

    private func startCut(_ urls: [URL]) throws {
        guard !urls.isEmpty else { throw FileOperationError.emptySelection }
        try clearPendingCut(restoreVisibility: true)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.writeObjects(urls as [NSURL]) else {
            throw FileOperationError.processFailed(L10n.text("无法写入系统剪贴板"))
        }
        if store.config.hideCutItems {
            try FileOperations.setHidden(true, for: urls)
        }
        try store.update { config in
            config.pendingCutPaths = urls.map(\.path)
            config.pendingCutItemsHidden = config.hideCutItems
        }
    }

    private func pastePendingCutItems() throws -> Bool {
        let sources = pendingCutURLs()
        guard !sources.isEmpty else {
            try clearPendingCut(restoreVisibility: false)
            return false
        }
        let selected = selectedURLs()
        let destination = selected.count == 1 && isDirectory(selected[0])
            ? selected[0]
            : try targetDirectory()
        let normalizedDestination = destination.standardizedFileURL
        let movingSources = sources.filter {
            $0.deletingLastPathComponent().standardizedFileURL != normalizedDestination
        }
        let unchanged = sources.filter {
            $0.deletingLastPathComponent().standardizedFileURL == normalizedDestination
        }
        let moved = try FileOperations.moveReturningTargets(movingSources, to: normalizedDestination)
        if store.config.pendingCutItemsHidden {
            try FileOperations.setHidden(false, for: unchanged + moved)
        }
        try clearPendingCut(restoreVisibility: false)
        return true
    }

    private func clearPendingCut(restoreVisibility: Bool) throws {
        let pending = pendingCutURLs()
        if restoreVisibility, store.config.pendingCutItemsHidden {
            try FileOperations.setHidden(false, for: pending)
        }
        try store.update {
            $0.pendingCutPaths = []
            $0.pendingCutItemsHidden = false
        }
    }

    private func pendingCutURLs() -> [URL] {
        store.config.pendingCutPaths
            .map { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    private func chooseDestinationAndTransfer(action: String) throws -> Bool {
        let panel = NSOpenPanel()
        panel.title = L10n.text(action == "copy" ? "选择复制目标目录" : "选择移动目标目录")
        panel.prompt = L10n.text(action == "copy" ? "复制到这里" : "移动到这里")
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let destination = panel.url else { return false }
        let urls = selectedURLs()
        if action == "copy" { try FileOperations.copy(urls, to: destination) }
        else { try FileOperations.move(urls, to: destination) }
        return true
    }

    private func addToFavorites(_ directory: URL) throws {
        let normalized = directory.standardizedFileURL
        guard !store.config.favorites.contains(where: { $0.expandedURL.standardizedFileURL == normalized }) else { return }
        let home = ConfigStore.userHomeDirectory.standardizedFileURL.path
        let path: String
        if normalized.path == home {
            path = "~"
        } else if normalized.path.hasPrefix(home + "/") {
            path = "~/" + String(normalized.path.dropFirst(home.count + 1))
        } else {
            path = normalized.path
        }
        try store.update { config in
            config.favorites.append(Destination(
                id: UUID().uuidString,
                name: normalized.lastPathComponent,
                path: path,
                enabled: true
            ))
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

    private func isDirectory(_ url: URL) -> Bool {
        var value: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &value) && value.boolValue
    }

    private func isImage(_ url: URL) -> Bool {
        let extensions: Set<String> = ["png", "jpg", "jpeg", "heic", "heif", "webp", "gif", "tif", "tiff", "bmp", "icns"]
        return extensions.contains(url.pathExtension.lowercased())
    }

    private func updateDirectoryURLs() {
        var urls = [URL(fileURLWithPath: "/", isDirectory: true)]
        if store.config.includeExternalVolumes {
            let volumes = FileManager.default.mountedVolumeURLs(
                includingResourceValuesForKeys: [.volumeIsInternalKey],
                options: [.skipHiddenVolumes]
            ) ?? []
            urls.append(contentsOf: volumes)
        }
        controller.directoryURLs = Set(urls)
    }

    private func open(urls: [URL], appName: String, bundleIdentifiers: [String]) throws {
        let workspace = NSWorkspace.shared
        guard let appURL = bundleIdentifiers.compactMap({ workspace.urlForApplication(withBundleIdentifier: $0) }).first else {
            throw FileOperationError.applicationNotFound(appName)
        }
        workspace.open(urls, withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
    }

    private func requestTerminalOpen(
        _ application: TerminalApplication,
        mode: TerminalOpenMode,
        directories: [URL]
    ) throws {
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: application.bundleIdentifier) != nil else {
            throw FileOperationError.applicationNotFound(application.displayName)
        }
        let request = TerminalLaunchRequest(application: application, mode: mode, directories: directories)
        guard let url = TerminalAutomation.requestURL(for: request), NSWorkspace.shared.open(url) else {
            throw FileOperationError.processFailed(L10n.format("无法请求 %@ 打开目录", application.displayName))
        }
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
