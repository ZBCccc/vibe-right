import AppKit
import Foundation

final class FinderActionCoordinator {
    private let store = ConfigStore.shared

    func perform(_ request: FinderActionRequest) {
        NSApp.activate(ignoringOtherApps: true)
        do {
            let performed: Bool
            switch request.action {
            case .createCustomFile:
                performed = try createCustomFile(request)
            case .copyToCustomDestination:
                performed = try transfer(request, moving: false)
            case .moveToCustomDestination:
                performed = try transfer(request, moving: true)
            case .repairFilename:
                performed = try repairFilenames(request)
            case .confirmPermanentDelete:
                performed = try confirmPermanentDelete(request)
            case .archive:
                performed = try performArchiveAction(request)
            }
            if performed, store.config.playSound { NSSound(named: "Glass")?.play() }
        } catch {
            showError(error)
        }
    }

    private func createCustomFile(_ request: FinderActionRequest) throws -> Bool {
        guard let directory = request.targetedURL else {
            throw FileOperationError.noTargetDirectory
        }
        let values = try directory.resourceValues(forKeys: [.isDirectoryKey])
        guard values.isDirectory == true else { throw FileOperationError.notDirectory(directory) }

        let nameField = NSTextField(string: L10n.text("未命名"))
        let extensionField = NSTextField(string: "")
        nameField.placeholderString = L10n.text("文件名")
        extensionField.placeholderString = "txt"
        nameField.widthAnchor.constraint(equalToConstant: 260).isActive = true
        extensionField.widthAnchor.constraint(equalToConstant: 260).isActive = true

        let form = NSGridView(views: [
            [NSTextField(labelWithString: L10n.text("文件名")), nameField],
            [NSTextField(labelWithString: L10n.text("后缀")), extensionField]
        ])
        form.rowSpacing = 8
        form.columnSpacing = 12
        form.yPlacement = .center

        let alert = NSAlert()
        alert.messageText = L10n.text("自定义创建新文件")
        alert.informativeText = L10n.text("输入文件名和可选后缀。") + "\n" + directory.path
        alert.alertStyle = .informational
        alert.accessoryView = form
        alert.addButton(withTitle: L10n.text("创建"))
        alert.addButton(withTitle: L10n.text("取消"))
        alert.window.initialFirstResponder = nameField
        nameField.selectText(nil)
        guard alert.runModal() == .alertFirstButtonReturn else { return false }

        let url = try FileOperations.createCustomFile(
            named: nameField.stringValue,
            fileExtension: extensionField.stringValue,
            in: directory
        )
        if store.config.autoOpenNewFile { NSWorkspace.shared.open(url) }
        return true
    }

    private func transfer(_ request: FinderActionRequest, moving: Bool) throws -> Bool {
        guard !request.selectedURLs.isEmpty else { throw FileOperationError.emptySelection }
        let panel = NSOpenPanel()
        panel.title = L10n.text(moving ? "选择移动目标目录" : "选择复制目标目录")
        panel.prompt = L10n.text(moving ? "移动到这里" : "复制到这里")
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if let targetedURL = request.targetedURL {
            panel.directoryURL = targetedURL
        }
        guard panel.runModal() == .OK, let destination = panel.url else { return false }
        if moving {
            try FileOperations.move(request.selectedURLs, to: destination)
        } else {
            try FileOperations.copy(request.selectedURLs, to: destination)
        }
        return true
    }

    private func repairFilenames(_ request: FinderActionRequest) throws -> Bool {
        let repairs = try FileOperations.proposedFilenameRepairs(for: request.selectedURLs)
        guard !repairs.isEmpty else {
            throw FileOperationError.processFailed(L10n.text("未发现可高置信度修复的乱码文件名"))
        }
        let preview = repairs.prefix(8).map {
            "\($0.source.lastPathComponent)  →  \($0.target.lastPathComponent)"
        }.joined(separator: "\n")
        let remaining = repairs.count > 8
            ? "\n" + L10n.format("…以及另外 %d 项", repairs.count - 8)
            : ""
        let alert = NSAlert()
        alert.messageText = L10n.text("确认修复乱码文件名？")
        alert.informativeText = preview + remaining
        alert.alertStyle = .informational
        alert.addButton(withTitle: L10n.text("修复"))
        alert.addButton(withTitle: L10n.text("取消"))
        guard alert.runModal() == .alertFirstButtonReturn else { return false }
        try FileOperations.applyFilenameRepairs(repairs)
        return true
    }

    private func confirmPermanentDelete(_ request: FinderActionRequest) throws -> Bool {
        guard !request.selectedURLs.isEmpty else { throw FileOperationError.emptySelection }
        let alert = NSAlert()
        alert.messageText = L10n.text("彻底删除所选项目？")
        alert.informativeText = L10n.text("此操作不会移入废纸篓，删除后无法恢复。")
        alert.alertStyle = .critical
        alert.addButton(withTitle: L10n.text("彻底删除"))
        alert.addButton(withTitle: L10n.text("取消"))
        guard alert.runModal() == .alertFirstButtonReturn else { return false }
        try FileOperations.deletePermanently(request.selectedURLs)
        return true
    }

    private func performArchiveAction(_ request: FinderActionRequest) throws -> Bool {
        guard !request.selectedURLs.isEmpty else { throw FileOperationError.emptySelection }
        guard let argument = request.argument, let tool = ToolActionID(rawValue: argument) else {
            throw FileOperationError.processFailed(L10n.text("无法识别压缩操作"))
        }

        if tool == .customCompression {
            guard let options = promptCustomCompressionOptions() else { return false }
            if options.deleteOriginals, !confirmDeletingOriginals(afterCompression: true) {
                return false
            }
            _ = try FileOperations.createArchives(from: request.selectedURLs, options: options)
            return true
        }

        if let options = compressionOptions(for: tool) {
            var resolved = options
            if requiresCompressionPassword(tool) {
                guard let password = promptNewArchivePassword() else { return false }
                resolved.password = password
            }
            if resolved.deleteOriginals, !confirmDeletingOriginals(afterCompression: true) {
                return false
            }
            _ = try FileOperations.createArchives(from: request.selectedURLs, options: resolved)
            return true
        }

        if let options = extractionOptions(for: tool) {
            if options.deleteArchives, !confirmDeletingOriginals(afterCompression: false) {
                return false
            }
            return try extractInteractively(request.selectedURLs, options: options)
        }

        throw FileOperationError.processFailed(L10n.text("无法识别压缩操作"))
    }

    private func compressionOptions(for tool: ToolActionID) -> ArchiveCompressionOptions? {
        switch tool {
        case .compress7Z:
            return ArchiveCompressionOptions(format: .sevenZip)
        case .compressZIP:
            return ArchiveCompressionOptions(format: .zip)
        case .compress7ZSeparate:
            return ArchiveCompressionOptions(format: .sevenZip, separateArchives: true)
        case .compressZIPSeparate:
            return ArchiveCompressionOptions(format: .zip, separateArchives: true)
        case .encryptCompress7Z:
            return ArchiveCompressionOptions(format: .sevenZip)
        case .encryptCompressZIP:
            return ArchiveCompressionOptions(format: .zip)
        case .encryptCompress7ZSeparate:
            return ArchiveCompressionOptions(format: .sevenZip, separateArchives: true)
        case .encryptCompressZIPSeparate:
            return ArchiveCompressionOptions(format: .zip, separateArchives: true)
        case .compress7ZDeleteOriginals:
            return ArchiveCompressionOptions(format: .sevenZip, deleteOriginals: true)
        case .compressZIPDeleteOriginals:
            return ArchiveCompressionOptions(format: .zip, deleteOriginals: true)
        case .compress7ZSeparateDeleteOriginals:
            return ArchiveCompressionOptions(
                format: .sevenZip,
                separateArchives: true,
                deleteOriginals: true
            )
        case .compressZIPSeparateDeleteOriginals:
            return ArchiveCompressionOptions(
                format: .zip,
                separateArchives: true,
                deleteOriginals: true
            )
        default:
            return nil
        }
    }

    private func requiresCompressionPassword(_ tool: ToolActionID) -> Bool {
        switch tool {
        case .encryptCompress7Z, .encryptCompressZIP,
             .encryptCompress7ZSeparate, .encryptCompressZIPSeparate:
            return true
        default:
            return false
        }
    }

    private func extractionOptions(for tool: ToolActionID) -> ArchiveExtractionOptions? {
        switch tool {
        case .extractArchive:
            return ArchiveExtractionOptions(destination: .currentFolder)
        case .extractArchiveSeparate:
            return ArchiveExtractionOptions(destination: .separateFolder)
        case .extractArchiveDeleteOriginal:
            return ArchiveExtractionOptions(destination: .currentFolder, deleteArchives: true)
        case .extractArchiveSeparateDeleteOriginal:
            return ArchiveExtractionOptions(destination: .separateFolder, deleteArchives: true)
        default:
            return nil
        }
    }

    private func promptCustomCompressionOptions() -> ArchiveCompressionOptions? {
        let format = NSPopUpButton(frame: .zero, pullsDown: false)
        format.addItems(withTitles: ["7z", "ZIP"])
        format.widthAnchor.constraint(equalToConstant: 240).isActive = true

        let separate = NSButton(
            checkboxWithTitle: L10n.text("分别为每个项目创建压缩包"),
            target: nil,
            action: nil
        )
        let deleteOriginals = NSButton(
            checkboxWithTitle: L10n.text("成功后删除原文件"),
            target: nil,
            action: nil
        )
        let password = NSSecureTextField(string: "")
        let confirmation = NSSecureTextField(string: "")
        password.placeholderString = L10n.text("留空表示不加密")
        confirmation.placeholderString = L10n.text("再次输入密码")
        password.widthAnchor.constraint(equalToConstant: 240).isActive = true
        confirmation.widthAnchor.constraint(equalToConstant: 240).isActive = true

        let form = NSGridView(views: [
            [NSTextField(labelWithString: L10n.text("压缩格式")), format],
            [NSTextField(labelWithString: L10n.text("加密密码")), password],
            [NSTextField(labelWithString: L10n.text("确认密码")), confirmation]
        ])
        form.rowSpacing = 8
        form.columnSpacing = 12
        form.yPlacement = .center

        let options = NSStackView(views: [form, separate, deleteOriginals])
        options.orientation = .vertical
        options.alignment = .leading
        options.spacing = 10

        let alert = NSAlert()
        alert.messageText = L10n.text("自定义压缩")
        alert.informativeText = L10n.text("选择格式、归档方式和可选加密密码。")
        alert.alertStyle = .informational
        alert.accessoryView = options
        alert.addButton(withTitle: L10n.text("压缩"))
        alert.addButton(withTitle: L10n.text("取消"))

        while alert.runModal() == .alertFirstButtonReturn {
            let enteredPassword = password.stringValue
            if !enteredPassword.isEmpty, enteredPassword != confirmation.stringValue {
                showError(FileOperationError.processFailed(L10n.text("两次输入的密码不一致")))
                continue
            }
            return ArchiveCompressionOptions(
                format: format.indexOfSelectedItem == 0 ? .sevenZip : .zip,
                separateArchives: separate.state == .on,
                deleteOriginals: deleteOriginals.state == .on,
                password: enteredPassword
            )
        }
        return nil
    }

    private func promptNewArchivePassword() -> String? {
        let password = NSSecureTextField(string: "")
        let confirmation = NSSecureTextField(string: "")
        password.placeholderString = L10n.text("密码")
        confirmation.placeholderString = L10n.text("再次输入密码")
        password.widthAnchor.constraint(equalToConstant: 260).isActive = true
        confirmation.widthAnchor.constraint(equalToConstant: 260).isActive = true
        let form = NSGridView(views: [
            [NSTextField(labelWithString: L10n.text("密码")), password],
            [NSTextField(labelWithString: L10n.text("确认密码")), confirmation]
        ])
        form.rowSpacing = 8
        form.columnSpacing = 12

        let alert = NSAlert()
        alert.messageText = L10n.text("设置加密密码")
        alert.informativeText = L10n.text("密码只在本次压缩期间保存在内存中。")
        alert.alertStyle = .informational
        alert.accessoryView = form
        alert.addButton(withTitle: L10n.text("继续"))
        alert.addButton(withTitle: L10n.text("取消"))

        while alert.runModal() == .alertFirstButtonReturn {
            guard !password.stringValue.isEmpty else {
                showError(FileOperationError.processFailed(L10n.text("密码不能为空")))
                continue
            }
            guard password.stringValue == confirmation.stringValue else {
                showError(FileOperationError.processFailed(L10n.text("两次输入的密码不一致")))
                continue
            }
            return password.stringValue
        }
        return nil
    }

    private func extractInteractively(
        _ archives: [URL],
        options: ArchiveExtractionOptions
    ) throws -> Bool {
        var performed = false
        for archive in archives {
            var password: String?
            while true {
                do {
                    var resolved = options
                    resolved.password = password
                    _ = try FileOperations.extractArchives([archive], options: resolved)
                    performed = true
                    break
                } catch FileOperationError.archivePasswordRequired {
                    guard let entered = promptArchivePassword(for: archive, incorrect: false) else {
                        return performed
                    }
                    password = entered
                } catch FileOperationError.invalidArchivePassword {
                    guard let entered = promptArchivePassword(for: archive, incorrect: true) else {
                        return performed
                    }
                    password = entered
                }
            }
        }
        return performed
    }

    private func promptArchivePassword(for archive: URL, incorrect: Bool) -> String? {
        let password = NSSecureTextField(string: "")
        password.placeholderString = L10n.text("密码")
        password.widthAnchor.constraint(equalToConstant: 260).isActive = true
        let alert = NSAlert()
        alert.messageText = incorrect
            ? L10n.text("密码错误，请重试")
            : L10n.text("请输入压缩包密码")
        alert.informativeText = archive.lastPathComponent
        alert.alertStyle = incorrect ? .warning : .informational
        alert.accessoryView = password
        alert.addButton(withTitle: L10n.text("继续"))
        alert.addButton(withTitle: L10n.text("取消"))
        alert.window.initialFirstResponder = password
        guard alert.runModal() == .alertFirstButtonReturn else { return nil }
        return password.stringValue.isEmpty ? nil : password.stringValue
    }

    private func confirmDeletingOriginals(afterCompression: Bool) -> Bool {
        let alert = NSAlert()
        alert.messageText = L10n.text(
            afterCompression
                ? "压缩成功后彻底删除原文件？"
                : "解压成功后彻底删除原压缩包？"
        )
        alert.informativeText = L10n.text(
            afterCompression
                ? "只有在压缩包通过完整性校验后才会删除，删除后无法恢复。"
                : "只有在全部内容安全解压后才会删除，删除后无法恢复。"
        )
        alert.alertStyle = .critical
        alert.addButton(withTitle: L10n.text("继续"))
        alert.addButton(withTitle: L10n.text("取消"))
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = L10n.text("操作失败")
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }
}
