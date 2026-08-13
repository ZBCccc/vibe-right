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

    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = L10n.text("操作失败")
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }
}
