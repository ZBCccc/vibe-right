import AppKit
import FinderSync

final class MainWindowController: NSWindowController {
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 660),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "灵犀右键"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.minSize = NSSize(width: 820, height: 560)
        window.center()
        window.contentViewController = MainViewController()
        super.init(window: window)
    }

    required init?(coder: NSCoder) { nil }
}

private enum SettingsSection: Int, CaseIterable {
    case general
    case newFiles
    case destinations
    case toolbox
    case about

    var title: String {
        switch self {
        case .general: return "通用设置"
        case .newFiles: return "新建文件"
        case .destinations: return "发送到与目录"
        case .toolbox: return "工具箱"
        case .about: return "关于"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape.fill"
        case .newFiles: return "doc.badge.plus"
        case .destinations: return "folder.badge.gearshape"
        case .toolbox: return "square.grid.2x2.fill"
        case .about: return "info.circle.fill"
        }
    }
}

private final class ControlAction: NSObject {
    let callback: (NSControl) -> Void
    init(_ callback: @escaping (NSControl) -> Void) { self.callback = callback }
    @objc func invoke(_ sender: NSControl) { callback(sender) }
}

final class MainViewController: NSViewController {
    private let store = ConfigStore.shared
    private let sidebar = NSVisualEffectView()
    private let scrollView = NSScrollView()
    private let contentStack = NSStackView()
    private var selectedSection: SettingsSection = .general
    private var sectionButtons: [NSButton] = []
    private var actionRetainers: [ControlAction] = []

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 960, height: 660))
        configureLayout()
        buildSidebar()
        renderSelectedSection()
    }

    private func configureLayout() {
        sidebar.material = .sidebar
        sidebar.blendingMode = .behindWindow
        sidebar.state = .active
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(sidebar)

        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 16
        contentStack.edgeInsets = NSEdgeInsets(top: 58, left: 34, bottom: 34, right: 34)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(contentStack)
        scrollView.documentView = documentView

        NSLayoutConstraint.activate([
            sidebar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: view.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: 224),

            scrollView.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            documentView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            documentView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            documentView.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),

            contentStack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            contentStack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            contentStack.topAnchor.constraint(equalTo: documentView.topAnchor),
            contentStack.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),
            contentStack.widthAnchor.constraint(equalTo: documentView.widthAnchor)
        ])
    }

    private func buildSidebar() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(stack)

        let symbol = NSImageView(image: NSImage(systemSymbolName: "cursorarrow.click.2", accessibilityDescription: nil) ?? NSImage())
        symbol.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 38, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.white, .systemPurple]))
        symbol.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(symbol)
        stack.setCustomSpacing(8, after: symbol)

        let title = label("灵犀右键", size: 20, weight: .bold)
        stack.addArrangedSubview(title)
        let version = label("原生 Finder 效率工具 · 0.1.0", size: 11, color: .secondaryLabelColor)
        stack.addArrangedSubview(version)
        stack.setCustomSpacing(28, after: version)

        for section in SettingsSection.allCases {
            let button = NSButton(title: section.title, target: self, action: #selector(selectSection(_:)))
            button.tag = section.rawValue
            button.image = NSImage(systemSymbolName: section.symbol, accessibilityDescription: nil)
            button.imagePosition = .imageLeading
            button.alignment = .left
            button.bezelStyle = .recessed
            button.isBordered = false
            button.font = .systemFont(ofSize: 14, weight: .medium)
            button.contentTintColor = .labelColor
            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(equalToConstant: 180).isActive = true
            button.heightAnchor.constraint(equalToConstant: 36).isActive = true
            stack.addArrangedSubview(button)
            sectionButtons.append(button)
        }

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -22),
            stack.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 64),
            symbol.widthAnchor.constraint(equalToConstant: 48),
            symbol.heightAnchor.constraint(equalToConstant: 48)
        ])
        updateSidebarSelection()
    }

    @objc private func selectSection(_ sender: NSButton) {
        guard let section = SettingsSection(rawValue: sender.tag) else { return }
        selectedSection = section
        updateSidebarSelection()
        renderSelectedSection()
    }

    private func updateSidebarSelection() {
        for button in sectionButtons {
            let selected = button.tag == selectedSection.rawValue
            button.contentTintColor = selected ? .systemPurple : .labelColor
            button.font = .systemFont(ofSize: 14, weight: selected ? .semibold : .medium)
        }
    }

    private func renderSelectedSection() {
        store.reload()
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        actionRetainers.removeAll()
        contentStack.addArrangedSubview(pageTitle(selectedSection.title))

        switch selectedSection {
        case .general: renderGeneral()
        case .newFiles: renderTemplates()
        case .destinations: renderDestinations()
        case .toolbox: renderTools()
        case .about: renderAbout()
        }

        for child in contentStack.arrangedSubviews {
            child.translatesAutoresizingMaskIntoConstraints = false
            child.widthAnchor.constraint(equalTo: contentStack.widthAnchor, constant: -68).isActive = true
        }
    }

    private func renderGeneral() {
        let enabled = FIFinderSyncController.isExtensionEnabled
        let status = statusView(
            title: enabled ? "Finder 扩展已启用" : "Finder 扩展尚未启用",
            subtitle: enabled ? "右键菜单会在 Finder 中自动生效。" : "需要在系统设置中显式启用一次。",
            symbol: enabled ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
            color: enabled ? .systemGreen : .systemOrange
        )
        let manage = NSButton(title: "管理扩展…", target: self, action: #selector(openExtensionManagement))
        manage.bezelStyle = .rounded
        status.addArrangedSubview(manage)
        contentStack.addArrangedSubview(card(title: "扩展状态", symbol: "puzzlepiece.extension", content: status))

        let settings = verticalStack()
        settings.addArrangedSubview(switchRow(
            title: "显示菜单图标",
            subtitle: "在 Finder 菜单项前显示系统符号",
            value: store.config.showIcons
        ) { [weak self] value in self?.updateConfig { $0.showIcons = value } })
        settings.addArrangedSubview(divider())
        settings.addArrangedSubview(switchRow(
            title: "操作完成提示音",
            subtitle: "成功执行右键动作后播放轻提示音",
            value: store.config.playSound
        ) { [weak self] value in self?.updateConfig { $0.playSound = value } })
        settings.addArrangedSubview(divider())
        settings.addArrangedSubview(switchRow(
            title: "新建文件后自动打开",
            subtitle: "使用默认应用打开新创建的文件",
            value: store.config.autoOpenNewFile
        ) { [weak self] value in self?.updateConfig { $0.autoOpenNewFile = value } })
        contentStack.addArrangedSubview(card(title: "显示与行为", symbol: "slider.horizontal.3", content: settings))

        let scope = statusView(
            title: "使用范围：系统磁盘",
            subtitle: "扩展监听根目录，因此本机普通 Finder 目录均可使用。网络卷和部分云盘目录由系统权限决定。",
            symbol: "internaldrive",
            color: .systemBlue
        )
        contentStack.addArrangedSubview(card(title: "作用范围", symbol: "scope", content: scope))
    }

    private func renderTemplates() {
        let intro = descriptionLabel("开启的模板会出现在 Finder 的“新建文件”子菜单中。名称冲突时会自动追加序号，不覆盖已有文件。")
        contentStack.addArrangedSubview(intro)

        let list = verticalStack()
        for (index, template) in store.config.templates.enumerated() {
            let subtitle = template.isDirectory ? "目录" : ".\(template.fileExtension) 文件"
            list.addArrangedSubview(switchRow(title: template.name, subtitle: subtitle, value: template.enabled) { [weak self] value in
                self?.updateConfig { config in config.templates[index].enabled = value }
            })
            if index < store.config.templates.count - 1 { list.addArrangedSubview(divider()) }
        }
        contentStack.addArrangedSubview(card(title: "内置模板", symbol: "doc.on.doc", content: list))

        let reset = NSButton(title: "恢复默认模板", target: self, action: #selector(resetTemplates))
        reset.bezelStyle = .rounded
        contentStack.addArrangedSubview(reset)
    }

    private func renderDestinations() {
        contentStack.addArrangedSubview(descriptionLabel("这些目录同时用于“复制到”“移动到”和“常用目录”。真实路径保存在本机配置中。"))

        let list = verticalStack()
        for (index, destination) in store.config.destinations.enumerated() {
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 12
            let toggle = NSButton(checkboxWithTitle: destination.name, target: nil, action: nil)
            toggle.state = destination.enabled ? .on : .off
            bind(toggle) { [weak self] control in
                self?.updateConfig { $0.destinations[index].enabled = (control as! NSButton).state == .on }
            }
            row.addArrangedSubview(toggle)
            let path = label(destination.path, size: 12, color: .secondaryLabelColor)
            path.setContentHuggingPriority(.defaultLow, for: .horizontal)
            row.addArrangedSubview(path)
            let remove = NSButton(image: NSImage(systemSymbolName: "trash", accessibilityDescription: "移除") ?? NSImage(), target: nil, action: nil)
            remove.isBordered = false
            bind(remove) { [weak self] _ in
                self?.updateConfig { $0.destinations.remove(at: index) }
                self?.renderSelectedSection()
            }
            row.addArrangedSubview(remove)
            list.addArrangedSubview(row)
            if index < store.config.destinations.count - 1 { list.addArrangedSubview(divider()) }
        }
        contentStack.addArrangedSubview(card(title: "目标目录", symbol: "folder", content: list))

        let add = NSButton(title: "添加目录…", target: self, action: #selector(addDestination))
        add.bezelStyle = .rounded
        add.image = NSImage(systemSymbolName: "plus", accessibilityDescription: nil)
        contentStack.addArrangedSubview(add)
    }

    private func renderTools() {
        contentStack.addArrangedSubview(descriptionLabel("只保留你真正使用的动作。更改会在下一次打开 Finder 右键菜单时生效。"))
        let list = verticalStack()
        for (index, tool) in ToolActionID.allCases.enumerated() {
            list.addArrangedSubview(switchRow(
                title: tool.title,
                subtitle: toolSubtitle(tool),
                value: store.config.enabledTools.contains(tool),
                symbol: tool.symbolName
            ) { [weak self] value in
                self?.updateConfig { config in
                    if value { config.enabledTools.insert(tool) }
                    else { config.enabledTools.remove(tool) }
                }
            })
            if index < ToolActionID.allCases.count - 1 { list.addArrangedSubview(divider()) }
        }
        contentStack.addArrangedSubview(card(title: "Finder 动作", symbol: "wrench.and.screwdriver", content: list))
    }

    private func renderAbout() {
        let hero = verticalStack(spacing: 12)
        let icon = NSImageView(image: NSImage(systemSymbolName: "cursorarrow.click.2", accessibilityDescription: nil) ?? NSImage())
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 54, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.systemPurple, .systemIndigo]))
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.heightAnchor.constraint(equalToConstant: 72).isActive = true
        hero.addArrangedSubview(icon)
        hero.addArrangedSubview(label("灵犀右键 0.1.0", size: 20, weight: .bold))
        hero.addArrangedSubview(descriptionLabel("独立实现的原生 macOS Finder 效率工具。基于公开 Finder Sync API，不依赖注入、辅助功能模拟或私有框架。"))
        contentStack.addArrangedSubview(card(title: "关于项目", symbol: "sparkles", content: hero))

        let path = ConfigStore.defaultConfigURL.path
        let details = verticalStack(spacing: 8)
        details.addArrangedSubview(label("配置文件", size: 13, weight: .semibold))
        let pathLabel = descriptionLabel(path)
        pathLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        pathLabel.isSelectable = true
        details.addArrangedSubview(pathLabel)
        contentStack.addArrangedSubview(card(title: "本机数据", symbol: "externaldrive", content: details))
    }

    @objc private func openExtensionManagement() {
        FIFinderSyncController.showExtensionManagementInterface()
    }

    @objc private func resetTemplates() {
        updateConfig { $0.templates = AppConfig.defaults.templates }
        renderSelectedSection()
    }

    @objc private func addDestination() {
        guard let window = view.window else { return }
        let panel = NSOpenPanel()
        panel.title = "选择常用目录"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            let path = url.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~", options: [.anchored])
            self?.updateConfig { config in
                config.destinations.append(Destination(id: UUID().uuidString, name: url.lastPathComponent, path: path, enabled: true))
            }
            self?.renderSelectedSection()
        }
    }

    private func updateConfig(_ transform: (inout AppConfig) -> Void) {
        do { try store.update(transform) }
        catch { showError(error) }
    }

    private func bind(_ control: NSControl, callback: @escaping (NSControl) -> Void) {
        let action = ControlAction(callback)
        actionRetainers.append(action)
        control.target = action
        control.action = #selector(ControlAction.invoke(_:))
    }

    private func switchRow(
        title: String,
        subtitle: String,
        value: Bool,
        symbol: String? = nil,
        changed: @escaping (Bool) -> Void
    ) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        if let symbol {
            let icon = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage())
            icon.contentTintColor = .systemPurple
            icon.translatesAutoresizingMaskIntoConstraints = false
            icon.widthAnchor.constraint(equalToConstant: 24).isActive = true
            row.addArrangedSubview(icon)
        }

        let text = verticalStack(spacing: 3)
        text.addArrangedSubview(label(title, size: 13, weight: .medium))
        text.addArrangedSubview(label(subtitle, size: 11, color: .secondaryLabelColor))
        text.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(text)

        let toggle = NSSwitch()
        toggle.state = value ? .on : .off
        bind(toggle) { control in changed((control as! NSSwitch).state == .on) }
        row.addArrangedSubview(toggle)
        return row
    }

    private func card(title: String, symbol: String, content: NSView) -> NSView {
        let box = NSBox()
        box.boxType = .custom
        box.cornerRadius = 14
        box.borderWidth = 1
        box.borderColor = NSColor.separatorColor.withAlphaComponent(0.45)
        box.fillColor = NSColor.controlBackgroundColor.withAlphaComponent(0.75)
        box.titlePosition = .noTitle

        let container = NSView()
        let stack = verticalStack(spacing: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        let heading = NSStackView()
        heading.orientation = .horizontal
        heading.spacing = 8
        let icon = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage())
        icon.contentTintColor = .systemPurple
        heading.addArrangedSubview(icon)
        heading.addArrangedSubview(label(title, size: 15, weight: .semibold))
        stack.addArrangedSubview(heading)
        stack.addArrangedSubview(content)
        stretchArrangedSubviews(in: stack)
        if let nestedStack = content as? NSStackView, nestedStack.orientation == .vertical {
            stretchArrangedSubviews(in: nestedStack)
        }
        box.contentView = container
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -18)
        ])
        return box
    }

    private func statusView(title: String, subtitle: String, symbol: String, color: NSColor) -> NSStackView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        let icon = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage())
        icon.contentTintColor = color
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 28).isActive = true
        row.addArrangedSubview(icon)
        let text = verticalStack(spacing: 3)
        text.addArrangedSubview(label(title, size: 13, weight: .semibold))
        text.addArrangedSubview(label(subtitle, size: 11, color: .secondaryLabelColor))
        text.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(text)
        return row
    }

    private func toolSubtitle(_ tool: ToolActionID) -> String {
        switch tool {
        case .copyName: return "将所选名称逐行写入剪贴板"
        case .copyPath: return "复制绝对路径"
        case .fileInfo: return "计算 MD5 或 SHA-256"
        case .createFolderFromName: return "创建同名目录并移入文件"
        case .toggleHidden: return "切换 Finder 隐藏属性"
        case .openTerminal: return "在系统终端打开目录"
        case .openWarp: return "使用 Warp 打开目录"
        case .openITerm2: return "使用 iTerm2 打开目录"
        case .openVSCode: return "使用 VS Code 打开目录"
        case .openCursor: return "使用 Cursor 打开目录"
        case .openGoLand: return "使用 GoLand 打开目录"
        case .convertPNG: return "旁路生成 PNG，不覆盖原图"
        case .convertJPEG: return "以 90% 质量生成 JPEG"
        }
    }

    private func pageTitle(_ text: String) -> NSTextField {
        let value = label(text, size: 28, weight: .bold)
        return value
    }

    private func descriptionLabel(_ text: String) -> NSTextField {
        let value = label(text, size: 12, color: .secondaryLabelColor)
        value.maximumNumberOfLines = 0
        value.lineBreakMode = .byWordWrapping
        return value
    }

    private func label(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .labelColor) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.font = .systemFont(ofSize: size, weight: weight)
        field.textColor = color
        return field
    }

    private func verticalStack(spacing: CGFloat = 12) -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = spacing
        return stack
    }

    private func stretchArrangedSubviews(in stack: NSStackView) {
        for child in stack.arrangedSubviews {
            child.translatesAutoresizingMaskIntoConstraints = false
            child.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
    }

    private func divider() -> NSBox {
        let divider = NSBox()
        divider.boxType = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return divider
    }

    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "保存失败"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.beginSheetModal(for: view.window ?? NSWindow())
    }
}
