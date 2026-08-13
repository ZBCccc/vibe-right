import AppKit
import CoreImage
import Foundation

@main
struct CoreTests {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("VibeRightTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let template = FileTemplate(id: "json", name: "JSON", fileExtension: "json", enabled: true, isDirectory: false)
        let first = try FileOperations.create(template: template, in: root)
        let second = try FileOperations.create(template: template, in: root)
        precondition(first.lastPathComponent == "未命名.json")
        precondition(second.lastPathComponent == "未命名 2.json")
        let firstContents = try Data(contentsOf: first)
        precondition(String(data: firstContents, encoding: .utf8) == "{}\n")

        let rtfTemplate = FileTemplate(id: "rtf", name: "RTF", fileExtension: "rtf", enabled: true, isDirectory: false)
        let xmlTemplate = FileTemplate(id: "xml", name: "XML", fileExtension: "xml", enabled: true, isDirectory: false)
        let rtf = try FileOperations.create(template: rtfTemplate, in: root)
        let xml = try FileOperations.create(template: xmlTemplate, in: root)
        let rtfContents = try Data(contentsOf: rtf)
        let xmlContents = try Data(contentsOf: xml)
        precondition(String(data: rtfContents, encoding: .utf8)?.hasPrefix("{\\rtf1") == true)
        precondition(String(data: xmlContents, encoding: .utf8)?.contains("<root/>") == true)

        let templateSourceDirectory = root.appendingPathComponent("template-source", isDirectory: true)
        let templateStorage = root.appendingPathComponent("template-storage", isDirectory: true)
        let templateOutput = root.appendingPathComponent("template-output", isDirectory: true)
        try FileManager.default.createDirectory(at: templateSourceDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: templateOutput, withIntermediateDirectories: true)
        let templateSource = templateSourceDirectory.appendingPathComponent("brief.custom")
        try Data("template contents".utf8).write(to: templateSource)
        let managedTemplate = try FileOperations.importTemplate(from: templateSource, into: templateStorage)
        try FileManager.default.removeItem(at: templateSource)
        let customTemplate = FileTemplate(
            id: "custom",
            name: "Brief",
            fileExtension: "custom",
            enabled: true,
            isDirectory: false,
            templatePath: managedTemplate.path
        )
        let customFile = try FileOperations.create(template: customTemplate, in: templateOutput)
        let customContents = try Data(contentsOf: customFile)
        precondition(String(data: customContents, encoding: .utf8) == "template contents")

        let word = try FileOperations.create(
            template: FileTemplate(id: "docx", name: "Word", fileExtension: "docx", enabled: true, isDirectory: false),
            in: root
        )
        let spreadsheet = try FileOperations.create(
            template: FileTemplate(id: "xlsx", name: "Excel", fileExtension: "xlsx", enabled: true, isDirectory: false),
            in: root
        )
        let presentation = try FileOperations.create(
            template: FileTemplate(id: "pptx", name: "PowerPoint", fileExtension: "pptx", enabled: true, isDirectory: false),
            in: root
        )
        let wordEntries = try zipEntries(at: word)
        let spreadsheetEntries = try zipEntries(at: spreadsheet)
        let presentationEntries = try zipEntries(at: presentation)
        precondition(wordEntries.contains("word/document.xml"))
        precondition(spreadsheetEntries.contains("xl/worksheets/sheet1.xml"))
        precondition(presentationEntries.contains("ppt/slides/slide1.xml"))

        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let builtInTemplateDirectory = repositoryRoot
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("Templates", isDirectory: true)
        let wpsTemplates = AppConfig.defaultTemplates.filter { ["wps", "et", "dps"].contains($0.id) }
        precondition(wpsTemplates.map(\.name) == ["WPS 文字", "WPS 表格", "WPS 演示"])
        let compoundDocumentHeader = Data([0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1])
        for template in wpsTemplates {
            let source = builtInTemplateDirectory.appendingPathComponent("Blank.\(template.fileExtension)")
            let created = try FileOperations.create(
                template: template,
                in: root,
                builtInTemplateDirectory: builtInTemplateDirectory
            )
            let sourceData = try Data(contentsOf: source)
            let createdData = try Data(contentsOf: created)
            precondition(createdData == sourceData)
            precondition(Data(createdData.prefix(compoundDocumentHeader.count)) == compoundDocumentHeader)
            let description = try fileDescription(at: source)
            precondition(description.contains("Composite Document File V2 Document"))
            precondition(!description.contains("Author:"))
            precondition(!description.contains("Last Saved By:"))
        }

        let aiTemplate = AppConfig.defaultTemplates.first(where: { $0.id == "ai" })!
        let aiDocument = try FileOperations.create(template: aiTemplate, in: root)
        let aiData = try Data(contentsOf: aiDocument)
        precondition(String(data: aiData.prefix(5), encoding: .ascii) == "%PDF-")
        let aiPDF = CGPDFDocument(aiDocument as CFURL)
        precondition(aiPDF?.numberOfPages == 1)
        let aiMediaBox = aiPDF?.page(at: 1)?.getBoxRect(.mediaBox)
        precondition(abs((aiMediaBox?.width ?? 0) - 595.276) < 0.1)
        precondition(abs((aiMediaBox?.height ?? 0) - 841.89) < 0.1)

        let psdTemplate = AppConfig.defaultTemplates.first(where: { $0.id == "psd" })!
        let psdDocument = try FileOperations.create(template: psdTemplate, in: root)
        let psdData = try Data(contentsOf: psdDocument)
        precondition(String(data: psdData.prefix(4), encoding: .ascii) == "8BPS")
        let psdBitmap = NSBitmapImageRep(data: psdData)
        precondition(psdBitmap?.pixelsWide == 1_890)
        precondition(psdBitmap?.pixelsHigh == 1_417)
        let aiDescription = try fileDescription(at: aiDocument)
        let psdDescription = try fileDescription(at: psdDocument)
        precondition(aiDescription.contains("PDF document"))
        precondition(psdDescription.contains("Adobe Photoshop Image"))
        let libreOffice = "/Applications/LibreOffice.app/Contents/MacOS/soffice"
        if FileManager.default.isExecutableFile(atPath: libreOffice) {
            try validateWithLibreOffice([word, spreadsheet, presentation], executable: libreOffice, root: root)
        }

        let destination = root.appendingPathComponent("destination", isDirectory: true)
        try FileOperations.copy([first], to: destination)
        try FileOperations.copy([first], to: destination)
        precondition(FileManager.default.fileExists(atPath: destination.appendingPathComponent("未命名.json").path))
        precondition(FileManager.default.fileExists(atPath: destination.appendingPathComponent("未命名 2.json").path))

        let configURL = root.appendingPathComponent("config.json")
        let store = ConfigStore(configURL: configURL)
        try store.update {
            $0.playSound = false
            $0.terminalOpenMode = .tab
            $0.iTermOpenMode = .tab
            $0.templates[0].showInMainMenu = true
            $0.destinations[0].name = "下载目录"
            $0.destinations.swapAt(0, 1)
            $0.toolOrder.removeAll { $0 == .copyPath }
            $0.toolOrder.insert(.copyPath, at: 0)
            $0.toolCustomTitles[ToolActionID.copyPath.rawValue] = "复制完整路径"
            $0.applications.swapAt(0, 1)
            $0.applications[1].name = "系统终端"
        }
        let reloaded = ConfigStore(configURL: configURL)
        precondition(reloaded.config.playSound == false)
        precondition(reloaded.config.schemaVersion == AppConfig.defaults.schemaVersion)
        precondition(reloaded.config.favorites == AppConfig.defaultFavorites)
        precondition(reloaded.config.applications[0].id == "iterm2")
        precondition(reloaded.config.applications[1].id == "terminal")
        precondition(reloaded.config.applications[1].name == "系统终端")
        precondition(reloaded.config.toolOrder.first == .copyPath)
        precondition(reloaded.config.title(for: .copyPath) == "复制完整路径")
        precondition(reloaded.config.orderedTools(from: [.copyName, .copyPath]) == [.copyPath, .copyName])
        precondition(reloaded.config.terminalOpenMode == .tab)
        precondition(reloaded.config.iTermOpenMode == .tab)
        precondition(reloaded.config.templates[0].showInMainMenu)
        precondition(reloaded.config.destinations[1].name == "下载目录")
        precondition(reloaded.config.enabledIconPresets == Set(FileIconPreset.allCases))
        precondition(reloaded.config.showMenuBarIcon)
        precondition(!reloaded.config.includeExternalVolumes)
        precondition(!reloaded.config.mergeFileActions)
        precondition(!reloaded.config.mergeImageActions)
        precondition(!reloaded.config.mergeApplicationActions)
        precondition(!reloaded.config.hideCutItems)
        precondition(reloaded.config.pendingCutPaths.isEmpty)
        precondition(!reloaded.config.pendingCutItemsHidden)
        precondition(Set(AppConfig.defaultApplications.map(\.id)).count == AppConfig.defaultApplications.count)
        precondition(AppConfig.defaultApplications.contains(where: { $0.id == "sublime-text" }))
        precondition(AppConfig.defaultApplications.contains(where: { $0.id == "android-studio" }))
        precondition(AppConfig.defaultApplications.contains(where: { $0.id == "rubymine" }))
        precondition(Set(AppConfig.defaultTemplates.map(\.id)).isSuperset(of: ["wps", "et", "dps"]))
        precondition(AppConfig.defaultTemplates.first(where: { $0.id == "ai" })?.enabled == false)
        precondition(AppConfig.defaultTemplates.first(where: { $0.id == "psd" })?.enabled == false)

        let internalTarget = URL(fileURLWithPath: "/Users/example/Documents", isDirectory: true)
        let externalTarget = URL(fileURLWithPath: "/Volumes/External", isDirectory: true)
        let selectedFile = internalTarget.appendingPathComponent("selected.txt")
        precondition(FinderScope.contextURLs(selected: [], targeted: nil).isEmpty)
        precondition(FinderScope.contextURLs(selected: [], targeted: externalTarget) == [externalTarget])
        precondition(FinderScope.contextURLs(selected: [selectedFile], targeted: externalTarget) == [selectedFile])
        precondition(!FinderScope.isExternalVolume(internalTarget))
        precondition(FinderScope.isExternalVolume(externalTarget))

        let legacyConfigURL = root.appendingPathComponent("legacy-config.json")
        let legacyConfig = """
        {
          "templates": [],
          "destinations": [],
          "enabledTools": ["copyPath"],
          "showIcons": true,
          "autoOpenNewFile": false,
          "playSound": true
        }
        """
        try Data(legacyConfig.utf8).write(to: legacyConfigURL)
        let migrated = ConfigStore(configURL: legacyConfigURL)
        precondition(migrated.config.schemaVersion == AppConfig.defaults.schemaVersion)
        precondition(migrated.config.enabledTools.contains(.cut))
        precondition(migrated.config.templates.contains(where: { $0.id == "rtf" }))
        precondition(migrated.config.templates.contains(where: { $0.id == "xml" }))
        precondition(migrated.config.templates.contains(where: { $0.id == "wps" }))
        precondition(migrated.config.templates.contains(where: { $0.id == "et" }))
        precondition(migrated.config.templates.contains(where: { $0.id == "dps" }))
        precondition(migrated.config.templates.contains(where: { $0.id == "ai" }))
        precondition(migrated.config.templates.contains(where: { $0.id == "psd" }))
        precondition(migrated.config.enabledTools.contains(.copyPath))
        precondition(migrated.config.applications.first(where: { $0.id == "cursor" })?.enabled == true)
        precondition(migrated.config.applications.first(where: { $0.id == "warp" })?.enabled == true)
        precondition(migrated.config.applications.first(where: { $0.id == "iterm2" })?.enabled == true)
        precondition(migrated.config.enabledTools.contains(.shareAirDrop))
        precondition(migrated.config.enabledTools.contains(.dissolveFolder))
        precondition(migrated.config.enabledTools.contains(.toggleFileExtension))
        precondition(migrated.config.enabledTools.contains(.generateQRCode))
        try migrated.update { config in
            for id in ["cursor", "warp", "iterm2"] {
                if let index = config.applications.firstIndex(where: { $0.id == id }) {
                    config.applications[index].enabled = false
                }
            }
        }
        try migrated.update { $0.enabledTools.remove(.shareAirDrop) }
        let migratedReloaded = ConfigStore(configURL: legacyConfigURL)
        precondition(migratedReloaded.config.applications.first(where: { $0.id == "cursor" })?.enabled == false)
        precondition(migratedReloaded.config.applications.first(where: { $0.id == "warp" })?.enabled == false)
        precondition(migratedReloaded.config.applications.first(where: { $0.id == "iterm2" })?.enabled == false)
        precondition(!migratedReloaded.config.enabledTools.contains(.shareAirDrop))

        let version2ConfigURL = root.appendingPathComponent("version-2-config.json")
        let version2Config = """
        {
          "schemaVersion": 2,
          "templates": [],
          "destinations": [],
          "enabledTools": ["copyPath"],
          "showIcons": true,
          "autoOpenNewFile": false,
          "playSound": true
        }
        """
        try Data(version2Config.utf8).write(to: version2ConfigURL)
        let version2Migrated = ConfigStore(configURL: version2ConfigURL)
        precondition(version2Migrated.config.schemaVersion == AppConfig.defaults.schemaVersion)
        precondition(version2Migrated.config.applications.first(where: { $0.id == "cursor" })?.enabled == false)
        precondition(version2Migrated.config.applications.first(where: { $0.id == "warp" })?.enabled == true)
        precondition(version2Migrated.config.applications.first(where: { $0.id == "iterm2" })?.enabled == true)
        precondition(version2Migrated.config.enabledTools.contains(.hideSelected))

        let version3ConfigURL = root.appendingPathComponent("version-3-config.json")
        let version3Config = """
        {
          "schemaVersion": 3,
          "templates": [],
          "destinations": [
            {"id": "work", "name": "Work", "path": "~/Work", "enabled": true}
          ],
          "enabledTools": ["copyPath", "openCursor"],
          "showIcons": true,
          "autoOpenNewFile": false,
          "playSound": true
        }
        """
        try Data(version3Config.utf8).write(to: version3ConfigURL)
        let version3Migrated = ConfigStore(configURL: version3ConfigURL)
        precondition(version3Migrated.config.schemaVersion == AppConfig.defaults.schemaVersion)
        precondition(version3Migrated.config.favorites == version3Migrated.config.destinations)
        precondition(version3Migrated.config.applications.first(where: { $0.id == "cursor" })?.enabled == true)
        precondition(version3Migrated.config.enabledTools.contains(.shareAirDrop))

        let version13ConfigURL = root.appendingPathComponent("version-13-config.json")
        let version13Config = """
        {
          "schemaVersion": 13,
          "templates": [
            {"id": "txt", "name": "TXT", "fileExtension": "txt", "enabled": true, "isDirectory": false}
          ],
          "applications": [
            {
              "id": "terminal",
              "name": "终端",
              "bundleIdentifiers": ["com.apple.Terminal"],
              "symbolName": "terminal",
              "enabled": false,
              "isBuiltIn": true
            }
          ],
          "enabledTools": ["copyPath"]
        }
        """
        try Data(version13Config.utf8).write(to: version13ConfigURL)
        let version13Migrated = ConfigStore(configURL: version13ConfigURL)
        precondition(version13Migrated.config.schemaVersion == AppConfig.defaults.schemaVersion)
        precondition(version13Migrated.config.applications.first(where: { $0.id == "terminal" })?.enabled == false)
        precondition(version13Migrated.config.applications.contains(where: { $0.id == "sublime-text" }))
        precondition(version13Migrated.config.enabledTools.contains(.generateQRCode))
        precondition(version13Migrated.config.templates[0].showInMainMenu == false)
        precondition(version13Migrated.config.terminalOpenMode == .window)
        precondition(version13Migrated.config.iTermOpenMode == .window)
        precondition(version13Migrated.config.templates.contains(where: { $0.id == "wps" }))
        precondition(version13Migrated.config.templates.contains(where: { $0.id == "et" }))
        precondition(version13Migrated.config.templates.contains(where: { $0.id == "dps" }))
        precondition(version13Migrated.config.templates.contains(where: { $0.id == "ai" }))
        precondition(version13Migrated.config.templates.contains(where: { $0.id == "psd" }))

        let version18ConfigURL = root.appendingPathComponent("version-18-config.json")
        let version18Config = """
        {
          "schemaVersion": 18,
          "templates": [
            {"id": "wps", "name": "我的 WPS", "fileExtension": "wps", "enabled": false, "isDirectory": false},
            {"id": "ai", "name": "我的 Ai", "fileExtension": "ai", "enabled": false, "isDirectory": false}
          ]
        }
        """
        try Data(version18Config.utf8).write(to: version18ConfigURL)
        let version18Migrated = ConfigStore(configURL: version18ConfigURL)
        precondition(version18Migrated.config.schemaVersion == AppConfig.defaults.schemaVersion)
        precondition(version18Migrated.config.templates.filter { $0.id == "wps" }.count == 1)
        precondition(version18Migrated.config.templates.first(where: { $0.id == "wps" })?.name == "我的 WPS")
        precondition(version18Migrated.config.templates.first(where: { $0.id == "wps" })?.enabled == false)
        precondition(version18Migrated.config.templates.contains(where: { $0.id == "et" }))
        precondition(version18Migrated.config.templates.contains(where: { $0.id == "dps" }))
        precondition(version18Migrated.config.templates.filter { $0.id == "ai" }.count == 1)
        precondition(version18Migrated.config.templates.first(where: { $0.id == "ai" })?.name == "我的 Ai")
        precondition(version18Migrated.config.templates.first(where: { $0.id == "ai" })?.enabled == false)
        precondition(version18Migrated.config.templates.contains(where: { $0.id == "psd" }))

        let automationDirectory = root.appendingPathComponent("quoted \"folder\" & line\nnext", isDirectory: true)
        try FileManager.default.createDirectory(at: automationDirectory, withIntermediateDirectories: true)
        let terminalRequest = TerminalLaunchRequest(
            application: .terminal,
            mode: .tab,
            directories: [automationDirectory]
        )
        let terminalURL = TerminalAutomation.requestURL(for: terminalRequest)
        precondition(terminalURL != nil)
        precondition(TerminalAutomation.parseRequestURL(terminalURL!) == terminalRequest)
        precondition(TerminalAutomation.serviceName(for: .terminal, mode: .window) == "New Terminal at Folder")
        precondition(TerminalAutomation.serviceName(for: .terminal, mode: .tab) == "New Terminal Tab at Folder")

        let iTermRequest = TerminalLaunchRequest(
            application: .iTerm2,
            mode: .window,
            directories: [automationDirectory]
        )
        let iTermURL = TerminalAutomation.requestURL(for: iTermRequest)
        precondition(iTermURL != nil)
        precondition(TerminalAutomation.parseRequestURL(iTermURL!) == iTermRequest)
        precondition(TerminalAutomation.serviceName(for: .iTerm2, mode: .window) == "New iTerm2 Window Here")
        precondition(TerminalAutomation.serviceName(for: .iTerm2, mode: .tab) == "New iTerm2 Tab Here")

        let hiddenFile = root.appendingPathComponent("visibility.txt")
        try Data("visible".utf8).write(to: hiddenFile)
        try FileOperations.setHidden(true, for: [hiddenFile])
        let hiddenValues = try hiddenFile.resourceValues(forKeys: [.isHiddenKey])
        precondition(hiddenValues.isHidden == true)
        try FileOperations.setHidden(false, for: [hiddenFile])
        let visibleValues = try hiddenFile.resourceValues(forKeys: [.isHiddenKey])
        precondition(visibleValues.isHidden == false)

        try FileOperations.toggleHiddenExtension(for: [hiddenFile])
        let hiddenExtensionValues = try hiddenFile.resourceValues(forKeys: [.hasHiddenExtensionKey])
        precondition(hiddenExtensionValues.hasHiddenExtension == true)
        try FileOperations.toggleHiddenExtension(for: [hiddenFile])
        let visibleExtensionValues = try hiddenFile.resourceValues(forKeys: [.hasHiddenExtensionKey])
        precondition(visibleExtensionValues.hasHiddenExtension == false)

        try FileManager.default.setAttributes([.posixPermissions: 0o444], ofItemAtPath: hiddenFile.path)
        try FileOperations.grantOwnerWritePermission(to: [hiddenFile])
        let permissions = try FileManager.default.attributesOfItem(atPath: hiddenFile.path)[.posixPermissions] as! NSNumber
        precondition(permissions.uint16Value & 0o200 != 0)

        let dissolveParent = root.appendingPathComponent("dissolve-parent", isDirectory: true)
        let dissolveFolder = dissolveParent.appendingPathComponent("folder", isDirectory: true)
        try FileManager.default.createDirectory(at: dissolveFolder, withIntermediateDirectories: true)
        try Data("existing".utf8).write(to: dissolveParent.appendingPathComponent("same.txt"))
        try Data("moved".utf8).write(to: dissolveFolder.appendingPathComponent("same.txt"))
        try Data("nested".utf8).write(to: dissolveFolder.appendingPathComponent("other.txt"))
        try FileOperations.dissolveFolders([dissolveFolder])
        precondition(!FileManager.default.fileExists(atPath: dissolveFolder.path))
        let existingContents = try Data(contentsOf: dissolveParent.appendingPathComponent("same.txt"))
        let movedContents = try Data(contentsOf: dissolveParent.appendingPathComponent("same 2.txt"))
        precondition(String(data: existingContents, encoding: .utf8) == "existing")
        precondition(String(data: movedContents, encoding: .utf8) == "moved")
        precondition(FileManager.default.fileExists(atPath: dissolveParent.appendingPathComponent("other.txt").path))

        let desktop = root.appendingPathComponent("Desktop", isDirectory: true)
        let shortcuts = try FileOperations.createDesktopShortcuts(for: [first], in: desktop)
        precondition(shortcuts.count == 1)
        let shortcutDestination = try FileManager.default.destinationOfSymbolicLink(atPath: shortcuts[0].path)
        precondition(URL(fileURLWithPath: shortcutDestination).standardizedFileURL == first.standardizedFileURL)

        let archiveParent = root.appendingPathComponent("archive-parent", isDirectory: true)
        try FileManager.default.createDirectory(at: archiveParent, withIntermediateDirectories: true)
        let archiveA = archiveParent.appendingPathComponent("a.txt")
        let archiveB = archiveParent.appendingPathComponent("b.txt")
        try Data("A".utf8).write(to: archiveA)
        try Data("B".utf8).write(to: archiveB)
        let archive = try FileOperations.createZIP(from: [archiveA, archiveB])
        precondition(FileManager.default.fileExists(atPath: archive.path))
        let extracted = try FileOperations.extractArchives([archive])
        precondition(extracted.count == 1)
        precondition(FileManager.default.fileExists(atPath: extracted[0].appendingPathComponent("a.txt").path))
        precondition(FileManager.default.fileExists(atPath: extracted[0].appendingPathComponent("b.txt").path))

        let sevenZipArchive = try FileOperations.create7Z(from: [archiveA, archiveB])
        precondition(FileManager.default.fileExists(atPath: sevenZipArchive.path))
        let sevenZipExtracted = try FileOperations.extractArchives([sevenZipArchive])
        precondition(sevenZipExtracted.count == 1)
        let sevenZipA = try Data(contentsOf: sevenZipExtracted[0].appendingPathComponent("a.txt"))
        let sevenZipB = try Data(contentsOf: sevenZipExtracted[0].appendingPathComponent("b.txt"))
        precondition(String(data: sevenZipA, encoding: .utf8) == "A")
        precondition(String(data: sevenZipB, encoding: .utf8) == "B")

        let disposable = root.appendingPathComponent("delete-me.txt")
        try Data("delete".utf8).write(to: disposable)
        try FileOperations.deletePermanently([disposable])
        precondition(!FileManager.default.fileExists(atPath: disposable.path))

        let imageURL = root.appendingPathComponent("pixel.png")
        let pixelPNG = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!
        try pixelPNG.write(to: imageURL)
        let qrText = "https://example.com/path?name=灵犀右键"
        let qrCode = try FileOperations.createQRCode(from: qrText, in: root)
        precondition(FileManager.default.fileExists(atPath: qrCode.path))
        let qrImage = CIImage(contentsOf: qrCode)
        precondition(qrImage != nil)
        let detector = CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: CIContext(),
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        )
        let qrFeature = detector?.features(in: qrImage!).compactMap { $0 as? CIQRCodeFeature }.first
        precondition(qrFeature?.messageString == qrText)
        let secondQRCode = try FileOperations.createQRCode(from: qrText, in: root)
        precondition(secondQRCode.lastPathComponent == "二维码 2.png")
        let qrData = try FileOperations.qrCodePNGData(from: qrText)
        precondition(!qrData.isEmpty)

        let googleURL = try TextServices.translationURL(
            for: " hello & 你好 ",
            provider: .google,
            preferredLanguages: ["zh-Hans-CN"]
        )
        let googleComponents = URLComponents(url: googleURL, resolvingAgainstBaseURL: false)
        let googleQuery: [String: String] = Dictionary(uniqueKeysWithValues: (googleComponents?.queryItems ?? []).compactMap {
            guard let value = $0.value else { return nil }
            return ($0.name, value)
        })
        precondition(googleURL.host == "translate.google.com")
        precondition(googleQuery["sl"] == "auto")
        precondition(googleQuery["tl"] == "zh-CN")
        precondition(googleQuery["text"] == "hello & 你好")
        precondition(googleQuery["op"] == "translate")

        let baiduURL = try TextServices.translationURL(
            for: "hello/#? 世界",
            provider: .baidu,
            preferredLanguages: ["zh-Hant-TW"]
        )
        precondition(baiduURL.host == "fanyi.baidu.com")
        precondition(baiduURL.path == "/mtpe-individual/transText")
        precondition(baiduURL.fragment?.removingPercentEncoding == "/auto/zh/hello/#? 世界")
        precondition(TextServices.translationTargetLanguage(preferredLanguages: ["ja-JP"]) == "ja")
        precondition(TextServices.translationTargetLanguage(preferredLanguages: ["en-US"]) == "en")

        let servicePasteboard = NSPasteboard.withUniqueName()
        defer { servicePasteboard.releaseGlobally() }
        servicePasteboard.declareTypes([.string], owner: nil)
        servicePasteboard.setString(qrText, forType: .string)
        let serviceInputText = try TextServices.readText(from: servicePasteboard)
        precondition(serviceInputText == qrText)
        try TextServices.writeQRCode(for: qrText, to: servicePasteboard)
        let serviceQRData = servicePasteboard.data(forType: .png)
        precondition(serviceQRData != nil)
        let serviceQRImage = serviceQRData.flatMap(CIImage.init(data:))
        precondition(serviceQRImage != nil)
        let serviceQRFeature = detector?.features(in: serviceQRImage!).compactMap { $0 as? CIQRCodeFeature }.first
        precondition(serviceQRFeature?.messageString == qrText)
        let macIconSets = try FileOperations.createMacIconSets([imageURL])
        precondition(macIconSets.count == 1)
        precondition(FileManager.default.fileExists(atPath: macIconSets[0].appendingPathComponent("icon_512x512@2x.png").path))
        let iosIconSets = try FileOperations.createIOSIconSets([imageURL])
        precondition(iosIconSets.count == 1)
        precondition(FileManager.default.fileExists(atPath: iosIconSets[0].appendingPathComponent("Contents.json").path))
        precondition(FileManager.default.fileExists(atPath: iosIconSets[0].appendingPathComponent("AppIcon-1024.png").path))
        try FileOperations.convertImagesToICNS([imageURL])
        precondition(FileManager.default.fileExists(atPath: root.appendingPathComponent("pixel.icns").path))
        try FileOperations.convertImagesToHEIC([imageURL])
        precondition(FileManager.default.fileExists(atPath: root.appendingPathComponent("pixel.heic").path))
        if FileManager.default.isExecutableFile(atPath: "/opt/homebrew/bin/cwebp") {
            try FileOperations.convertImagesToWebP([imageURL])
            precondition(FileManager.default.fileExists(atPath: root.appendingPathComponent("pixel.webp").path))
        }

        let iconTarget = root.appendingPathComponent("icon-target.txt")
        try Data("icon".utf8).write(to: iconTarget)
        try FileOperations.applyIconPreset(.book, to: [iconTarget])
        try FileOperations.applyCustomIcon(at: imageURL, to: [iconTarget])
        try FileOperations.removeCustomIcons(from: [iconTarget])

        precondition(FileOperations.repairedFilename("ä¸­æ–‡.txt") == "中文.txt")
        precondition(FileOperations.repairedFilename("normal-file.txt") == nil)
        let garbled = root.appendingPathComponent("ä¸­æ–‡.txt")
        let existingChinese = root.appendingPathComponent("中文.txt")
        try Data("garbled".utf8).write(to: garbled)
        try Data("existing".utf8).write(to: existingChinese)
        let filenameRepairs = try FileOperations.proposedFilenameRepairs(for: [garbled])
        precondition(filenameRepairs.count == 1)
        precondition(filenameRepairs[0].target.lastPathComponent == "中文 2.txt")
        try FileOperations.applyFilenameRepairs(filenameRepairs)
        precondition(!FileManager.default.fileExists(atPath: garbled.path))
        precondition(FileManager.default.fileExists(atPath: filenameRepairs[0].target.path))

        let cutSourceDirectory = root.appendingPathComponent("cut-source", isDirectory: true)
        let cutDestinationDirectory = root.appendingPathComponent("cut-destination", isDirectory: true)
        try FileManager.default.createDirectory(at: cutSourceDirectory, withIntermediateDirectories: true)
        let cutA = cutSourceDirectory.appendingPathComponent("a.txt")
        let cutB = cutSourceDirectory.appendingPathComponent("b.txt")
        try Data("A".utf8).write(to: cutA)
        try Data("B".utf8).write(to: cutB)
        let cutTargets = try FileOperations.moveReturningTargets([cutA, cutB], to: cutDestinationDirectory)
        precondition(cutTargets.count == 2)
        precondition(!FileManager.default.fileExists(atPath: cutA.path))
        precondition(!FileManager.default.fileExists(atPath: cutB.path))
        precondition(cutTargets.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })

        let sha1 = try FileOperations.checksum(of: first, algorithm: "sha1")
        let sha256 = try FileOperations.checksum(of: first, algorithm: "sha256")
        let sha512 = try FileOperations.checksum(of: first, algorithm: "sha512")
        precondition(sha1.count == 40)
        precondition(sha256.count == 64)
        precondition(sha512.count == 128)
        print("CoreTests passed")
    }

    private static func zipEntries(at url: URL) throws -> [String] {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-Z1", url.path]
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw FileOperationError.processFailed(output)
        }
        return output.split(separator: "\n").map(String.init)
    }

    private static func fileDescription(at url: URL) throws -> String {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/file")
        process.arguments = ["-b", url.path]
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw FileOperationError.processFailed(output)
        }
        return output
    }

    private static func validateWithLibreOffice(_ urls: [URL], executable: String, root: URL) throws {
        for (index, url) in urls.enumerated() {
            let outputDirectory = root.appendingPathComponent("libreoffice-output-\(index)", isDirectory: true)
            let profile = root.appendingPathComponent("libreoffice-profile-\(index)", isDirectory: true)
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = [
                "-env:UserInstallation=\(profile.absoluteString)",
                "--headless",
                "--convert-to", "pdf",
                "--outdir", outputDirectory.path,
                url.path
            ]
            process.standardOutput = pipe
            process.standardError = pipe
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            guard process.terminationStatus == 0 else {
                throw FileOperationError.processFailed("LibreOffice 无法打开 \(url.lastPathComponent)：\(output)")
            }
            let pdf = outputDirectory
                .appendingPathComponent(url.deletingPathExtension().lastPathComponent)
                .appendingPathExtension("pdf")
            guard FileManager.default.fileExists(atPath: pdf.path) else {
                throw FileOperationError.processFailed("LibreOffice 未能转换 \(url.lastPathComponent)：\(output)")
            }
        }
    }
}
