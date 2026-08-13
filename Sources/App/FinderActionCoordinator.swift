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

    private func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = L10n.text("操作失败")
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.runModal()
    }
}
