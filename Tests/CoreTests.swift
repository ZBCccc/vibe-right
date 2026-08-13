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
        try store.update { $0.playSound = false }
        let reloaded = ConfigStore(configURL: configURL)
        precondition(reloaded.config.playSound == false)
        precondition(reloaded.config.schemaVersion == 13)
        precondition(reloaded.config.favorites == AppConfig.defaultFavorites)
        precondition(reloaded.config.applications == AppConfig.defaultApplications)
        precondition(reloaded.config.enabledIconPresets == Set(FileIconPreset.allCases))
        precondition(reloaded.config.showMenuBarIcon)
        precondition(!reloaded.config.includeExternalVolumes)
        precondition(!reloaded.config.mergeFileActions)
        precondition(!reloaded.config.mergeImageActions)
        precondition(!reloaded.config.mergeApplicationActions)
        precondition(!reloaded.config.hideCutItems)
        precondition(reloaded.config.pendingCutPaths.isEmpty)
        precondition(!reloaded.config.pendingCutItemsHidden)

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
        precondition(migrated.config.schemaVersion == 13)
        precondition(migrated.config.enabledTools.contains(.cut))
        precondition(migrated.config.templates.contains(where: { $0.id == "rtf" }))
        precondition(migrated.config.templates.contains(where: { $0.id == "xml" }))
        precondition(migrated.config.enabledTools.contains(.copyPath))
        precondition(migrated.config.applications.first(where: { $0.id == "cursor" })?.enabled == true)
        precondition(migrated.config.applications.first(where: { $0.id == "warp" })?.enabled == true)
        precondition(migrated.config.applications.first(where: { $0.id == "iterm2" })?.enabled == true)
        precondition(migrated.config.enabledTools.contains(.shareAirDrop))
        precondition(migrated.config.enabledTools.contains(.dissolveFolder))
        precondition(migrated.config.enabledTools.contains(.toggleFileExtension))
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
        precondition(version2Migrated.config.schemaVersion == 13)
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
        precondition(version3Migrated.config.schemaVersion == 13)
        precondition(version3Migrated.config.favorites == version3Migrated.config.destinations)
        precondition(version3Migrated.config.applications.first(where: { $0.id == "cursor" })?.enabled == true)
        precondition(version3Migrated.config.enabledTools.contains(.shareAirDrop))

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
        let extracted = try FileOperations.extractZIP([archive])
        precondition(extracted.count == 1)
        precondition(FileManager.default.fileExists(atPath: extracted[0].appendingPathComponent("a.txt").path))
        precondition(FileManager.default.fileExists(atPath: extracted[0].appendingPathComponent("b.txt").path))

        let disposable = root.appendingPathComponent("delete-me.txt")
        try Data("delete".utf8).write(to: disposable)
        try FileOperations.deletePermanently([disposable])
        precondition(!FileManager.default.fileExists(atPath: disposable.path))

        let imageURL = root.appendingPathComponent("pixel.png")
        let pixelPNG = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")!
        try pixelPNG.write(to: imageURL)
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
