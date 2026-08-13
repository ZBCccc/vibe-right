import AppKit
import FinderSync
import UniformTypeIdentifiers

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
    case favorites
    case icons
    case toolbox
    case about

    var title: String {
        switch self {
        case .general: return "通用设置"
        case .newFiles: return "新建文件"
        case .destinations: return "发送文件到…"
        case .favorites: return "常用目录"
        case .icons: return "文件（夹）图标"
        case .toolbox: return "工具箱"
        case .about: return "关于"
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape.fill"
        case .newFiles: return "doc.badge.plus"
        case .destinations: return "folder.badge.gearshape"
        case .favorites: return "heart.fill"
        case .icons: return "photo.stack.fill"
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
        case .favorites: renderFavorites()
        case .icons: renderIcons()
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
            title: "显示菜单栏图标",
            subtitle: "关闭后仍可从应用或 Finder 菜单打开设置",
            value: store.config.showMenuBarIcon
        ) { [weak self] value in self?.updateConfig { $0.showMenuBarIcon = value } })
        settings.addArrangedSubview(divider())
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

        let scope = verticalStack()
        scope.addArrangedSubview(statusView(
            title: store.config.includeExternalVolumes ? "使用范围：系统磁盘 + 外接磁盘" : "使用范围：系统磁盘",
            subtitle: "网络卷和部分云盘目录仍由 macOS 与对应文件提供程序的权限决定。",
            symbol: store.config.includeExternalVolumes ? "externaldrive.connected.to.line.below" : "internaldrive",
            color: .systemBlue
        ))
        scope.addArrangedSubview(divider())
        scope.addArrangedSubview(switchRow(
            title: "包含外接磁盘",
            subtitle: "自动跟踪之后挂载或卸载的外置卷",
            value: store.config.includeExternalVolumes
        ) { [weak self] value in
            self?.updateConfig { $0.includeExternalVolumes = value }
            self?.renderSelectedSection()
        })
        contentStack.addArrangedSubview(card(title: "作用范围", symbol: "scope", content: scope))
    }

    private func renderTemplates() {
        let intro = descriptionLabel("开启的模板会出现在 Finder 的“新建文件”子菜单中。名称冲突时会自动追加序号，不覆盖已有文件。")
        contentStack.addArrangedSubview(intro)

        let list = verticalStack()
        for (index, template) in store.config.templates.enumerated() {
            let subtitle = template.isDirectory ? "目录" : ".\(template.fileExtension) 文件"
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 8
            let toggle = switchRow(title: template.name, subtitle: subtitle, value: template.enabled) { [weak self] value in
                self?.updateConfig { config in config.templates[index].enabled = value }
            }
            toggle.setContentHuggingPriority(.defaultLow, for: .horizontal)
            row.addArrangedSubview(toggle)

            let mainMenu = NSButton(checkboxWithTitle: "主菜单", target: nil, action: nil)
            mainMenu.toolTip = "直接显示在 Finder 右键主菜单，不收入“新建文件”子菜单"
            mainMenu.state = template.showInMainMenu ? .on : .off
            bind(mainMenu) { [weak self] control in
                self?.updateConfig {
                    $0.templates[index].showInMainMenu = (control as! NSButton).state == .on
                }
            }
            row.addArrangedSubview(mainMenu)

            row.addArrangedSubview(iconButton(symbol: "pencil", accessibilityLabel: "重命名模板") { [weak self] in
                self?.renameTemplate(at: index)
            })
            row.addArrangedSubview(reorderButtons(index: index, count: store.config.templates.count) { [weak self] offset in
                self?.moveTemplate(at: index, offset: offset)
            })
            if template.templatePath != nil {
                row.addArrangedSubview(iconButton(symbol: "trash", accessibilityLabel: "移除模板") { [weak self] in
                    self?.removeTemplate(at: index)
                })
            }
            list.addArrangedSubview(row)
            if index < store.config.templates.count - 1 { list.addArrangedSubview(divider()) }
        }
        contentStack.addArrangedSubview(card(title: "文件模板", symbol: "doc.on.doc", content: list))

        let add = NSButton(title: "添加模板文件…", target: self, action: #selector(addTemplate))
        add.bezelStyle = .rounded
        add.image = NSImage(systemSymbolName: "plus", accessibilityDescription: nil)
        contentStack.addArrangedSubview(add)

        let reset = NSButton(title: "恢复默认模板", target: self, action: #selector(resetTemplates))
        reset.bezelStyle = .rounded
        contentStack.addArrangedSubview(reset)
    }

    private func renderDestinations() {
        contentStack.addArrangedSubview(descriptionLabel("这些目录只用于“移动文件到…”和“复制文件到…”。每次操作也可以临时选择自定义路径。"))

        let switches = verticalStack()
        switches.addArrangedSubview(switchRow(
            title: "启用移动文件到…",
            subtitle: "在选择文件时显示移动菜单",
            value: store.config.moveEnabled
        ) { [weak self] value in self?.updateConfig { $0.moveEnabled = value } })
        switches.addArrangedSubview(divider())
        switches.addArrangedSubview(switchRow(
            title: "启用复制文件到…",
            subtitle: "在选择文件时显示复制菜单",
            value: store.config.copyEnabled
        ) { [weak self] value in self?.updateConfig { $0.copyEnabled = value } })
        contentStack.addArrangedSubview(card(title: "菜单开关", symbol: "switch.2", content: switches))

        let list = destinationList(
            store.config.destinations,
            setEnabled: { [weak self] index, value in
                self?.updateConfig { $0.destinations[index].enabled = value }
            },
            rename: { [weak self] index in self?.renameDestination(at: index, inFavorites: false) },
            move: { [weak self] index, offset in self?.moveDestination(at: index, offset: offset, inFavorites: false) },
            remove: { [weak self] index in
                self?.updateConfig { $0.destinations.remove(at: index) }
                self?.renderSelectedSection()
            }
        )
        contentStack.addArrangedSubview(card(title: "传送目录", symbol: "folder", content: list))

        let add = NSButton(title: "添加目录…", target: self, action: #selector(addDestination))
        add.bezelStyle = .rounded
        add.image = NSImage(systemSymbolName: "plus", accessibilityDescription: nil)
        contentStack.addArrangedSubview(add)
    }

    private func renderFavorites() {
        contentStack.addArrangedSubview(descriptionLabel("常用目录是独立的快速入口，不会自动出现在移动或复制菜单中。也可以在 Finder 中对文件夹执行“添加到常用目录”。"))

        let enabled = verticalStack()
        enabled.addArrangedSubview(switchRow(
            title: "启用常用目录",
            subtitle: "在 Finder 空白处和工具栏菜单中显示",
            value: store.config.favoritesEnabled
        ) { [weak self] value in self?.updateConfig { $0.favoritesEnabled = value } })
        contentStack.addArrangedSubview(card(title: "菜单开关", symbol: "heart", content: enabled))

        let list = destinationList(
            store.config.favorites,
            setEnabled: { [weak self] index, value in
                self?.updateConfig { $0.favorites[index].enabled = value }
            },
            rename: { [weak self] index in self?.renameDestination(at: index, inFavorites: true) },
            move: { [weak self] index, offset in self?.moveDestination(at: index, offset: offset, inFavorites: true) },
            remove: { [weak self] index in
                self?.updateConfig { $0.favorites.remove(at: index) }
                self?.renderSelectedSection()
            }
        )
        contentStack.addArrangedSubview(card(title: "常用目录", symbol: "heart.fill", content: list))

        let add = NSButton(title: "添加目录…", target: self, action: #selector(addFavorite))
        add.bezelStyle = .rounded
        add.image = NSImage(systemSymbolName: "plus", accessibilityDescription: nil)
        contentStack.addArrangedSubview(add)
    }

    private func destinationList(
        _ destinations: [Destination],
        setEnabled: @escaping (Int, Bool) -> Void,
        rename: @escaping (Int) -> Void,
        move: @escaping (Int, Int) -> Void,
        remove: @escaping (Int) -> Void
    ) -> NSStackView {
        let list = verticalStack()
        for (index, destination) in destinations.enumerated() {
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 12
            let toggle = NSButton(checkboxWithTitle: destination.name, target: nil, action: nil)
            toggle.state = destination.enabled ? .on : .off
            bind(toggle) { control in
                setEnabled(index, (control as! NSButton).state == .on)
            }
            row.addArrangedSubview(toggle)
            let path = label(destination.path, size: 12, color: .secondaryLabelColor)
            path.setContentHuggingPriority(.defaultLow, for: .horizontal)
            row.addArrangedSubview(path)
            row.addArrangedSubview(iconButton(symbol: "pencil", accessibilityLabel: "重命名") {
                rename(index)
            })
            row.addArrangedSubview(reorderButtons(index: index, count: destinations.count) { offset in
                move(index, offset)
            })
            row.addArrangedSubview(iconButton(symbol: "trash", accessibilityLabel: "移除") {
                remove(index)
            })
            list.addArrangedSubview(row)
            if index < destinations.count - 1 { list.addArrangedSubview(divider()) }
        }
        return list
    }

    private func renderIcons() {
        contentStack.addArrangedSubview(descriptionLabel("启用的图标会出现在 Finder 的“文件（夹）图标”子菜单中。内置图标由系统符号独立生成，不使用第三方素材。"))

        let presets = verticalStack()
        for (index, preset) in FileIconPreset.allCases.enumerated() {
            presets.addArrangedSubview(switchRow(
                title: preset.title,
                subtitle: "原创系统符号图标",
                value: store.config.enabledIconPresets.contains(preset),
                symbol: preset.symbolName
            ) { [weak self] value in
                self?.updateConfig { config in
                    if value { config.enabledIconPresets.insert(preset) }
                    else { config.enabledIconPresets.remove(preset) }
                }
            })
            if index < FileIconPreset.allCases.count - 1 { presets.addArrangedSubview(divider()) }
        }
        contentStack.addArrangedSubview(card(title: "内置图标", symbol: "square.grid.3x3", content: presets))

        if !store.config.customIcons.isEmpty {
            let customIcons = verticalStack()
            for (index, customIcon) in store.config.customIcons.enumerated() {
                let row = NSStackView()
                row.orientation = .horizontal
                row.alignment = .centerY
                row.spacing = 12
                let preview = NSImageView(image: NSImage(contentsOfFile: customIcon.path) ?? NSImage())
                preview.imageScaling = .scaleProportionallyUpOrDown
                preview.translatesAutoresizingMaskIntoConstraints = false
                preview.widthAnchor.constraint(equalToConstant: 28).isActive = true
                preview.heightAnchor.constraint(equalToConstant: 28).isActive = true
                row.addArrangedSubview(preview)
                let name = label(customIcon.name, size: 13, weight: .medium)
                name.setContentHuggingPriority(.defaultLow, for: .horizontal)
                row.addArrangedSubview(name)
                let remove = NSButton(
                    image: NSImage(systemSymbolName: "trash", accessibilityDescription: "移除图标") ?? NSImage(),
                    target: nil,
                    action: nil
                )
                remove.isBordered = false
                bind(remove) { [weak self] _ in self?.removeCustomIcon(at: index) }
                row.addArrangedSubview(remove)
                let toggle = NSSwitch()
                toggle.state = customIcon.enabled ? .on : .off
                bind(toggle) { [weak self] control in
                    self?.updateConfig { $0.customIcons[index].enabled = (control as! NSSwitch).state == .on }
                }
                row.addArrangedSubview(toggle)
                customIcons.addArrangedSubview(row)
                if index < store.config.customIcons.count - 1 { customIcons.addArrangedSubview(divider()) }
            }
            contentStack.addArrangedSubview(card(title: "自定义图标", symbol: "photo", content: customIcons))
        }

        let add = NSButton(title: "添加图标图片…", target: self, action: #selector(addCustomIcon))
        add.bezelStyle = .rounded
        add.image = NSImage(systemSymbolName: "plus", accessibilityDescription: nil)
        contentStack.addArrangedSubview(add)
    }

    private func renderTools() {
        contentStack.addArrangedSubview(descriptionLabel("只保留你真正使用的动作。更改会在下一次打开 Finder 右键菜单时生效。"))
        let list = verticalStack()
        let orderedTools = store.config.toolOrder
        for (index, tool) in orderedTools.enumerated() {
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 8
            let toggle = switchRow(
                title: store.config.title(for: tool),
                subtitle: toolSubtitle(tool),
                value: store.config.enabledTools.contains(tool),
                symbol: tool.symbolName
            ) { [weak self] value in
                self?.updateConfig { config in
                    if value { config.enabledTools.insert(tool) }
                    else { config.enabledTools.remove(tool) }
                }
            }
            toggle.setContentHuggingPriority(.defaultLow, for: .horizontal)
            row.addArrangedSubview(toggle)
            row.addArrangedSubview(iconButton(symbol: "pencil", accessibilityLabel: "自定义工具名称") { [weak self] in
                self?.renameTool(at: index)
            })
            if store.config.toolCustomTitles[tool.rawValue] != nil {
                row.addArrangedSubview(iconButton(symbol: "arrow.uturn.backward", accessibilityLabel: "恢复默认名称") { [weak self] in
                    self?.resetToolTitle(tool)
                })
            }
            row.addArrangedSubview(reorderButtons(index: index, count: orderedTools.count) { [weak self] offset in
                self?.moveTool(at: index, offset: offset)
            })
            list.addArrangedSubview(row)
            if index < orderedTools.count - 1 { list.addArrangedSubview(divider()) }
        }
        contentStack.addArrangedSubview(card(title: "Finder 动作", symbol: "wrench.and.screwdriver", content: list))

        let safety = verticalStack()
        safety.addArrangedSubview(switchRow(
            title: "剪切时隐藏所选项目",
            subtitle: "粘贴或取消剪切时会自动恢复显示",
            value: store.config.hideCutItems
        ) { [weak self] value in self?.updateConfig { $0.hideCutItems = value } })
        safety.addArrangedSubview(divider())
        safety.addArrangedSubview(switchRow(
            title: "彻底删除前再次确认",
            subtitle: "建议始终开启；彻底删除不会进入废纸篓",
            value: store.config.confirmPermanentDelete
        ) { [weak self] value in self?.updateConfig { $0.confirmPermanentDelete = value } })
        contentStack.addArrangedSubview(card(title: "安全选项", symbol: "exclamationmark.shield", content: safety))

        let grouping = verticalStack()
        grouping.addArrangedSubview(switchRow(
            title: "合并显示文件（夹）右键菜单",
            subtitle: "将通用文件动作收进一个子菜单",
            value: store.config.mergeFileActions
        ) { [weak self] value in self?.updateConfig { $0.mergeFileActions = value } })
        grouping.addArrangedSubview(divider())
        grouping.addArrangedSubview(switchRow(
            title: "合并显示图片转换右键菜单",
            subtitle: "将图片格式与图标集动作收进一个子菜单",
            value: store.config.mergeImageActions
        ) { [weak self] value in self?.updateConfig { $0.mergeImageActions = value } })
        grouping.addArrangedSubview(divider())
        grouping.addArrangedSubview(switchRow(
            title: "合并显示进入应用右键菜单",
            subtitle: "将所有外部应用入口收进一个子菜单",
            value: store.config.mergeApplicationActions
        ) { [weak self] value in self?.updateConfig { $0.mergeApplicationActions = value } })
        contentStack.addArrangedSubview(card(title: "菜单分组", symbol: "rectangle.3.group", content: grouping))

        let terminalBehavior = verticalStack()
        let modes = TerminalOpenMode.allCases
        terminalBehavior.addArrangedSubview(selectionRow(
            title: "系统终端打开方式",
            subtitle: "选择每次在新窗口或当前窗口的新标签页中打开",
            options: modes.map(\.title),
            selectedIndex: modes.firstIndex(of: store.config.terminalOpenMode) ?? 0
        ) { [weak self] index in
            guard modes.indices.contains(index) else { return }
            self?.updateConfig { $0.terminalOpenMode = modes[index] }
        })
        terminalBehavior.addArrangedSubview(divider())
        terminalBehavior.addArrangedSubview(selectionRow(
            title: "iTerm2 打开方式",
            subtitle: "选择每次在新窗口或当前窗口的新标签页中打开",
            options: modes.map(\.title),
            selectedIndex: modes.firstIndex(of: store.config.iTermOpenMode) ?? 0
        ) { [weak self] index in
            guard modes.indices.contains(index) else { return }
            self?.updateConfig { $0.iTermOpenMode = modes[index] }
        })
        contentStack.addArrangedSubview(card(title: "终端行为", symbol: "terminal", content: terminalBehavior))

        let applications = verticalStack()
        for (index, application) in store.config.applications.enumerated() {
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 12

            let icon = NSImageView(
                image: NSImage(systemSymbolName: application.symbolName, accessibilityDescription: nil) ?? NSImage()
            )
            icon.contentTintColor = .systemPurple
            icon.translatesAutoresizingMaskIntoConstraints = false
            icon.widthAnchor.constraint(equalToConstant: 24).isActive = true
            row.addArrangedSubview(icon)

            let installed = application.bundleIdentifiers.contains {
                NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil
            }
            let text = verticalStack(spacing: 3)
            text.addArrangedSubview(label(application.name, size: 13, weight: .medium))
            text.addArrangedSubview(label(
                installed ? "已安装" : "未检测到安装",
                size: 11,
                color: installed ? .systemGreen : .secondaryLabelColor
            ))
            text.setContentHuggingPriority(.defaultLow, for: .horizontal)
            row.addArrangedSubview(text)

            row.addArrangedSubview(iconButton(symbol: "pencil", accessibilityLabel: "重命名应用入口") { [weak self] in
                self?.renameApplication(at: index)
            })
            row.addArrangedSubview(reorderButtons(index: index, count: store.config.applications.count) { [weak self] offset in
                self?.moveApplication(at: index, offset: offset)
            })

            if !application.isBuiltIn {
                let remove = NSButton(
                    image: NSImage(systemSymbolName: "trash", accessibilityDescription: "移除") ?? NSImage(),
                    target: nil,
                    action: nil
                )
                remove.isBordered = false
                bind(remove) { [weak self] _ in
                    self?.updateConfig { $0.applications.remove(at: index) }
                    self?.renderSelectedSection()
                }
                row.addArrangedSubview(remove)
            }

            let toggle = NSSwitch()
            toggle.state = application.enabled ? .on : .off
            bind(toggle) { [weak self] control in
                self?.updateConfig { $0.applications[index].enabled = (control as! NSSwitch).state == .on }
            }
            row.addArrangedSubview(toggle)
            applications.addArrangedSubview(row)
            if index < store.config.applications.count - 1 { applications.addArrangedSubview(divider()) }
        }
        contentStack.addArrangedSubview(card(title: "进入应用", symbol: "app.badge", content: applications))

        let addApplication = NSButton(title: "添加应用…", target: self, action: #selector(addApplication))
        addApplication.bezelStyle = .rounded
        addApplication.image = NSImage(systemSymbolName: "plus", accessibilityDescription: nil)
        contentStack.addArrangedSubview(addApplication)
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
        updateConfig { config in
            let customTemplates = config.templates.filter { $0.templatePath != nil }
            config.templates = AppConfig.defaults.templates + customTemplates
        }
        renderSelectedSection()
    }

    @objc private func addTemplate() {
        guard let window = view.window else { return }
        let panel = NSOpenPanel()
        panel.title = "选择模板文件"
        panel.prompt = "添加模板"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.treatsFilePackagesAsDirectories = false
        panel.beginSheetModal(for: window) { [weak self] response in
            guard let self, response == .OK else { return }
            var imported: [URL] = []
            do {
                let templates = try panel.urls.map { source -> FileTemplate in
                    let managed = try FileOperations.importTemplate(from: source, into: self.store.templateStorageURL)
                    imported.append(managed)
                    return FileTemplate(
                        id: UUID().uuidString,
                        name: source.deletingPathExtension().lastPathComponent,
                        fileExtension: source.pathExtension,
                        enabled: true,
                        isDirectory: false,
                        templatePath: managed.path
                    )
                }
                try self.store.update { $0.templates.append(contentsOf: templates) }
                self.renderSelectedSection()
            } catch {
                for url in imported { try? FileManager.default.removeItem(at: url) }
                self.showError(error)
            }
        }
    }

    private func removeTemplate(at index: Int) {
        guard store.config.templates.indices.contains(index) else { return }
        let template = store.config.templates[index]
        do {
            if let templatePath = template.templatePath {
                let url = URL(fileURLWithPath: templatePath).standardizedFileURL
                let storagePath = store.templateStorageURL.standardizedFileURL.path + "/"
                guard url.path.hasPrefix(storagePath) else {
                    throw FileOperationError.processFailed("拒绝删除模板存储目录之外的文件")
                }
                if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                }
            }
            try store.update { $0.templates.remove(at: index) }
            renderSelectedSection()
        } catch {
            showError(error)
        }
    }

    private func renameTemplate(at index: Int) {
        guard store.config.templates.indices.contains(index) else { return }
        promptForName(title: "重命名模板", currentValue: store.config.templates[index].name) { [weak self] name in
            self?.updateConfig { $0.templates[index].name = name }
            self?.renderSelectedSection()
        }
    }

    private func moveTemplate(at index: Int, offset: Int) {
        let target = index + offset
        guard store.config.templates.indices.contains(index), store.config.templates.indices.contains(target) else { return }
        updateConfig { $0.templates.swapAt(index, target) }
        renderSelectedSection()
    }

    private func renameDestination(at index: Int, inFavorites: Bool) {
        let destinations = inFavorites ? store.config.favorites : store.config.destinations
        guard destinations.indices.contains(index) else { return }
        promptForName(
            title: inFavorites ? "重命名常用目录" : "重命名传送目录",
            currentValue: destinations[index].name
        ) { [weak self] name in
            self?.updateConfig { config in
                if inFavorites { config.favorites[index].name = name }
                else { config.destinations[index].name = name }
            }
            self?.renderSelectedSection()
        }
    }

    private func moveDestination(at index: Int, offset: Int, inFavorites: Bool) {
        let target = index + offset
        let destinations = inFavorites ? store.config.favorites : store.config.destinations
        guard destinations.indices.contains(index), destinations.indices.contains(target) else { return }
        updateConfig { config in
            if inFavorites { config.favorites.swapAt(index, target) }
            else { config.destinations.swapAt(index, target) }
        }
        renderSelectedSection()
    }

    private func renameTool(at index: Int) {
        guard store.config.toolOrder.indices.contains(index) else { return }
        let tool = store.config.toolOrder[index]
        promptForName(title: "自定义工具名称", currentValue: store.config.title(for: tool)) { [weak self] name in
            self?.updateConfig { config in
                if name == tool.title { config.toolCustomTitles.removeValue(forKey: tool.rawValue) }
                else { config.toolCustomTitles[tool.rawValue] = name }
            }
            self?.renderSelectedSection()
        }
    }

    private func resetToolTitle(_ tool: ToolActionID) {
        updateConfig { $0.toolCustomTitles.removeValue(forKey: tool.rawValue) }
        renderSelectedSection()
    }

    private func moveTool(at index: Int, offset: Int) {
        let target = index + offset
        guard store.config.toolOrder.indices.contains(index), store.config.toolOrder.indices.contains(target) else { return }
        updateConfig { $0.toolOrder.swapAt(index, target) }
        renderSelectedSection()
    }

    private func renameApplication(at index: Int) {
        guard store.config.applications.indices.contains(index) else { return }
        promptForName(title: "重命名应用入口", currentValue: store.config.applications[index].name) { [weak self] name in
            self?.updateConfig { $0.applications[index].name = name }
            self?.renderSelectedSection()
        }
    }

    private func moveApplication(at index: Int, offset: Int) {
        let target = index + offset
        guard store.config.applications.indices.contains(index), store.config.applications.indices.contains(target) else { return }
        updateConfig { $0.applications.swapAt(index, target) }
        renderSelectedSection()
    }

    private func promptForName(title: String, currentValue: String, completion: @escaping (String) -> Void) {
        guard let window = view.window else { return }
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = "名称会直接显示在 Finder 菜单中。"
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "取消")
        let field = NSTextField(string: currentValue)
        field.frame = NSRect(x: 0, y: 0, width: 300, height: 24)
        field.selectText(nil)
        alert.accessoryView = field
        alert.window.initialFirstResponder = field
        alert.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn else { return }
            let name = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, !name.contains("\n"), !name.contains("\r") else {
                NSSound.beep()
                return
            }
            completion(name)
        }
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

    @objc private func addFavorite() {
        guard let window = view.window else { return }
        let panel = NSOpenPanel()
        panel.title = "选择常用目录"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            let home = ConfigStore.userHomeDirectory.path
            let path = url.path.replacingOccurrences(of: home, with: "~", options: [.anchored])
            self?.updateConfig { config in
                guard !config.favorites.contains(where: { $0.expandedURL.standardizedFileURL == url.standardizedFileURL }) else { return }
                config.favorites.append(Destination(id: UUID().uuidString, name: url.lastPathComponent, path: path, enabled: true))
            }
            self?.renderSelectedSection()
        }
    }

    @objc private func addApplication() {
        guard let window = view.window else { return }
        let panel = NSOpenPanel()
        panel.title = "选择要加入 Finder 菜单的应用"
        panel.prompt = "添加应用"
        panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = false
        panel.allowedContentTypes = [.applicationBundle]
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            guard let bundle = Bundle(url: url), let bundleIdentifier = bundle.bundleIdentifier else {
                self?.showError(FileOperationError.processFailed("所选项目不是有效的 macOS 应用"))
                return
            }
            let displayName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? url.deletingPathExtension().lastPathComponent
            self?.updateConfig { config in
                if let index = config.applications.firstIndex(where: { $0.bundleIdentifiers.contains(bundleIdentifier) }) {
                    config.applications[index].enabled = true
                    return
                }
                config.applications.append(ExternalApplication(
                    id: UUID().uuidString,
                    name: displayName,
                    bundleIdentifiers: [bundleIdentifier],
                    symbolName: "app",
                    enabled: true,
                    isBuiltIn: false
                ))
            }
            self?.renderSelectedSection()
        }
    }

    @objc private func addCustomIcon() {
        guard let window = view.window else { return }
        let panel = NSOpenPanel()
        panel.title = "选择图标图片"
        panel.prompt = "添加图标"
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.image]
        panel.beginSheetModal(for: window) { [weak self] response in
            guard let self, response == .OK else { return }
            var imported: [URL] = []
            do {
                let icons = try panel.urls.map { source -> CustomFileIcon in
                    guard NSImage(contentsOf: source) != nil else {
                        throw FileOperationError.unsupportedImage(source)
                    }
                    let managed = try FileOperations.importTemplate(from: source, into: self.store.iconStorageURL)
                    imported.append(managed)
                    return CustomFileIcon(
                        id: UUID().uuidString,
                        name: source.deletingPathExtension().lastPathComponent,
                        path: managed.path,
                        enabled: true
                    )
                }
                try self.store.update { $0.customIcons.append(contentsOf: icons) }
                self.renderSelectedSection()
            } catch {
                for url in imported { try? FileManager.default.removeItem(at: url) }
                self.showError(error)
            }
        }
    }

    private func removeCustomIcon(at index: Int) {
        guard store.config.customIcons.indices.contains(index) else { return }
        let customIcon = store.config.customIcons[index]
        do {
            let url = URL(fileURLWithPath: customIcon.path).standardizedFileURL
            let storagePath = store.iconStorageURL.standardizedFileURL.path + "/"
            guard url.path.hasPrefix(storagePath) else {
                throw FileOperationError.processFailed("拒绝删除图标存储目录之外的文件")
            }
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            try store.update { $0.customIcons.remove(at: index) }
            renderSelectedSection()
        } catch {
            showError(error)
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

    private func iconButton(
        symbol: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> NSButton {
        let button = NSButton(
            image: NSImage(systemSymbolName: symbol, accessibilityDescription: accessibilityLabel) ?? NSImage(),
            target: nil,
            action: nil
        )
        button.isBordered = false
        button.toolTip = accessibilityLabel
        bind(button) { _ in action() }
        return button
    }

    private func reorderButtons(
        index: Int,
        count: Int,
        move: @escaping (Int) -> Void
    ) -> NSStackView {
        let controls = NSStackView()
        controls.orientation = .horizontal
        controls.alignment = .centerY
        controls.spacing = 0
        let up = iconButton(symbol: "chevron.up", accessibilityLabel: "上移") { move(-1) }
        up.isEnabled = index > 0
        controls.addArrangedSubview(up)
        let down = iconButton(symbol: "chevron.down", accessibilityLabel: "下移") { move(1) }
        down.isEnabled = index + 1 < count
        controls.addArrangedSubview(down)
        return controls
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

    private func selectionRow(
        title: String,
        subtitle: String,
        options: [String],
        selectedIndex: Int,
        changed: @escaping (Int) -> Void
    ) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12

        let text = verticalStack(spacing: 3)
        text.addArrangedSubview(label(title, size: 13, weight: .medium))
        text.addArrangedSubview(label(subtitle, size: 11, color: .secondaryLabelColor))
        text.setContentHuggingPriority(.defaultLow, for: .horizontal)
        row.addArrangedSubview(text)

        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.addItems(withTitles: options)
        popup.selectItem(at: selectedIndex)
        bind(popup) { control in changed((control as! NSPopUpButton).indexOfSelectedItem) }
        row.addArrangedSubview(popup)
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
        case .createDesktopShortcut: return "在桌面创建指向所选项目的快捷方式"
        case .shareAirDrop: return "通过系统隔空投送分享所选项目"
        case .copyName: return "将所选名称逐行写入剪贴板"
        case .copyPath: return "复制绝对路径"
        case .fileInfo: return "计算 MD5、SHA-1、SHA-256 或 SHA-512"
        case .createFolderFromName: return "创建同名目录并移入文件"
        case .cut: return "写入文件剪贴板，并可从灵犀菜单移动到目标目录"
        case .dissolveFolder: return "将文件夹内容移到上一级并删除空文件夹"
        case .setWallpaper: return "将所选图片设置为桌面墙纸"
        case .addToFavorites: return "把所选文件夹加入常用目录"
        case .grantWritePermission: return "仅补充所有者写权限"
        case .hideAll: return "隐藏当前目录的直接子项"
        case .unhideAll: return "取消隐藏当前目录的直接子项"
        case .hideSelected: return "隐藏所选项目"
        case .unhideSelected: return "取消隐藏所选项目"
        case .toggleFileExtension: return "切换 Finder 的扩展名显示属性"
        case .repairFilename: return "高置信度识别乱码，预览确认后再重命名"
        case .generateQRCode: return "把所选项目的绝对路径生成离线 PNG 二维码"
        case .permanentDelete: return "绕过废纸篓删除，默认必须二次确认"
        case .compress7Z: return "使用系统归档引擎在当前目录生成 7z 压缩包"
        case .compressZIP: return "使用系统 ZIP 工具在当前目录生成压缩包"
        case .extractArchive: return "将 ZIP 或 7z 解压到同名目录"
        case .toggleHidden: return "切换 Finder 隐藏属性"
        case .openTerminal: return "在系统终端打开目录"
        case .openWarp: return "使用 Warp 打开目录"
        case .openITerm2: return "使用 iTerm2 打开目录"
        case .openVSCode: return "使用 VS Code 打开目录"
        case .openCursor: return "使用 Cursor 打开目录"
        case .openGoLand: return "使用 GoLand 打开目录"
        case .convertPNG: return "旁路生成 PNG，不覆盖原图"
        case .convertJPEG: return "以 90% 质量生成 JPEG"
        case .convertWebP: return "使用可用的 cwebp 旁路生成 WebP"
        case .convertHEIC: return "使用 macOS 图像服务生成 HEIC"
        case .convertICNS: return "生成包含标准尺寸的 ICNS"
        case .makeMacIconSet: return "生成完整 macOS .iconset 目录"
        case .makeIOSIconSet: return "生成带 Contents.json 的 AppIcon.appiconset"
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
