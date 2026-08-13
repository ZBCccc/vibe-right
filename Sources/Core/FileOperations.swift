import AppKit
import CoreImage
import Darwin
import Foundation
import ImageIO

enum FileOperationError: LocalizedError {
    case noTargetDirectory
    case notDirectory(URL)
    case emptySelection
    case templateMissing(URL)
    case unsupportedImage(URL)
    case applicationNotFound(String)
    case invalidCustomFileName
    case invalidCustomFileExtension
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case .noTargetDirectory: return L10n.text("无法确定目标目录")
        case .notDirectory(let url): return L10n.format("不是文件夹：%@", url.lastPathComponent)
        case .emptySelection: return L10n.text("请先选择文件或文件夹")
        case .templateMissing(let url): return L10n.format("模板文件不存在：%@", url.lastPathComponent)
        case .unsupportedImage(let url): return L10n.format("无法读取图片：%@", url.lastPathComponent)
        case .applicationNotFound(let name): return L10n.format("未安装 %@", name)
        case .invalidCustomFileName: return L10n.text("请输入有效的文件名")
        case .invalidCustomFileExtension: return L10n.text("请输入有效的文件后缀")
        case .processFailed(let message): return L10n.text(message)
        }
    }
}
enum FileOperations {
    private static let bundledTemplateFileNames = [
        "wps": "Blank.wps",
        "et": "Blank.et",
        "dps": "Blank.dps"
    ]

    struct FilenameRepair: Equatable {
        let source: URL
        let target: URL
    }

    static func uniqueURL(in directory: URL, preferredName: String, pathExtension: String = "") -> URL {
        let cleanExtension = pathExtension.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        func candidate(_ suffix: String) -> URL {
            var url = directory.appendingPathComponent(preferredName + suffix)
            if !cleanExtension.isEmpty { url.appendPathExtension(cleanExtension) }
            return url
        }

        var url = candidate("")
        var index = 2
        while FileManager.default.fileExists(atPath: url.path) {
            url = candidate(" \(index)")
            index += 1
        }
        return url
    }

    @discardableResult
    static func createCustomFile(
        named name: String,
        fileExtension: String,
        in directory: URL
    ) throws -> URL {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let invalidCharacters = CharacterSet(charactersIn: "/:").union(.controlCharacters)
        guard !cleanName.isEmpty,
              cleanName != ".",
              cleanName != "..",
              cleanName.rangeOfCharacter(from: invalidCharacters) == nil else {
            throw FileOperationError.invalidCustomFileName
        }

        let cleanExtension = fileExtension.trimmingCharacters(
            in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "."))
        )
        guard cleanExtension.rangeOfCharacter(from: invalidCharacters) == nil else {
            throw FileOperationError.invalidCustomFileExtension
        }

        let output = uniqueURL(
            in: directory,
            preferredName: cleanName,
            pathExtension: cleanExtension
        )
        guard FileManager.default.createFile(atPath: output.path, contents: Data()) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return output
    }

    @discardableResult
    static func create(
        template: FileTemplate,
        in directory: URL,
        builtInTemplateDirectory: URL? = nil
    ) throws -> URL {
        let baseName = L10n.text(template.isDirectory ? "新建文件夹" : "未命名")
        let url = uniqueURL(in: directory, preferredName: baseName, pathExtension: template.fileExtension)
        if let templatePath = template.templatePath {
            let source = URL(fileURLWithPath: templatePath)
            guard FileManager.default.fileExists(atPath: source.path) else {
                throw FileOperationError.templateMissing(source)
            }
            try FileManager.default.copyItem(at: source, to: url)
        } else if let fileName = bundledTemplateFileNames[template.id] {
            guard let resourceDirectory = builtInTemplateDirectory
                ?? Bundle.main.resourceURL?.appendingPathComponent("Templates", isDirectory: true) else {
                throw FileOperationError.processFailed("找不到内置模板资源目录")
            }
            let source = resourceDirectory.appendingPathComponent(fileName)
            guard FileManager.default.fileExists(atPath: source.path) else {
                throw FileOperationError.templateMissing(source)
            }
            try FileManager.default.copyItem(at: source, to: url)
        } else if template.isDirectory {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        } else if let officeKind = OfficeDocumentKind(fileExtension: template.fileExtension) {
            try createOfficeDocument(officeKind, at: url)
        } else if template.id == "ai" {
            try createIllustratorDocument(at: url)
        } else if template.id == "psd" {
            try createPhotoshopDocument(at: url)
        } else {
            let initialData: Data
            switch template.fileExtension.lowercased() {
            case "json": initialData = Data("{}\n".utf8)
            case "swift": initialData = Data("import Foundation\n\n".utf8)
            case "rtf": initialData = Data("{\\rtf1\\ansi\\deff0\n}\n".utf8)
            case "xml": initialData = Data("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<root/>\n".utf8)
            default: initialData = Data()
            }
            guard FileManager.default.createFile(atPath: url.path, contents: initialData) else {
                throw CocoaError(.fileWriteUnknown)
            }
        }
        return url
    }

    private static func createIllustratorDocument(at output: URL) throws {
        var mediaBox = CGRect(x: 0, y: 0, width: 595.276, height: 841.89)
        guard let consumer = CGDataConsumer(url: output as CFURL),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw FileOperationError.processFailed("无法创建 Ai 文档")
        }
        context.beginPDFPage(nil)
        context.setFillColor(NSColor.white.cgColor)
        context.fill(mediaBox)
        context.endPDFPage()
        context.closePDF()
    }

    private static func createPhotoshopDocument(at output: URL) throws {
        let width = 1_890
        let height = 1_417
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            throw FileOperationError.processFailed("无法创建 PSD 画布")
        }
        context.setFillColor(NSColor.white.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(
                output as CFURL,
                "com.adobe.photoshop-image" as CFString,
                1,
                nil
              ) else {
            throw FileOperationError.processFailed("当前系统不支持创建 PSD 文档")
        }
        let properties: [CFString: Any] = [
            kCGImagePropertyDPIWidth: 72,
            kCGImagePropertyDPIHeight: 72
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            try? FileManager.default.removeItem(at: output)
            throw FileOperationError.processFailed("PSD 文档编码失败")
        }
    }

    @discardableResult
    static func importTemplate(from source: URL, into storage: URL) throws -> URL {
        guard FileManager.default.fileExists(atPath: source.path) else {
            throw FileOperationError.templateMissing(source)
        }
        try FileManager.default.createDirectory(at: storage, withIntermediateDirectories: true)
        let isDirectory = try source.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
        let destination = uniqueURL(
            in: storage,
            preferredName: isDirectory ? source.lastPathComponent : source.deletingPathExtension().lastPathComponent,
            pathExtension: isDirectory ? "" : source.pathExtension
        )
        try FileManager.default.copyItem(at: source, to: destination)
        return destination
    }

    static func copy(_ sources: [URL], to destination: URL) throws {
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        for source in sources {
            let target = uniqueURL(
                in: destination,
                preferredName: source.deletingPathExtension().lastPathComponent,
                pathExtension: source.pathExtension
            )
            try FileManager.default.copyItem(at: source, to: target)
        }
    }

    static func move(_ sources: [URL], to destination: URL) throws {
        _ = try moveReturningTargets(sources, to: destination)
    }

    @discardableResult
    static func moveReturningTargets(_ sources: [URL], to destination: URL) throws -> [URL] {
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        var completed: [(source: URL, target: URL)] = []
        var targets: [URL] = []
        for source in sources {
            let target = uniqueURL(
                in: destination,
                preferredName: source.deletingPathExtension().lastPathComponent,
                pathExtension: source.pathExtension
            )
            do {
                try FileManager.default.moveItem(at: source, to: target)
                completed.append((source, target))
                targets.append(target)
            } catch {
                for move in completed.reversed() where FileManager.default.fileExists(atPath: move.target.path) {
                    try? FileManager.default.moveItem(at: move.target, to: move.source)
                }
                throw error
            }
        }
        return targets
    }

    static func createFoldersFromNames(for sources: [URL]) throws {
        for source in sources {
            let parent = source.deletingLastPathComponent()
            let folder = uniqueURL(in: parent, preferredName: source.deletingPathExtension().lastPathComponent)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
            try FileManager.default.moveItem(at: source, to: folder.appendingPathComponent(source.lastPathComponent))
        }
    }

    static func dissolveFolders(_ folders: [URL]) throws {
        guard !folders.isEmpty else { throw FileOperationError.emptySelection }
        let fileManager = FileManager.default
        var moves: [(source: URL, target: URL)] = []
        var reservedPaths = Set<String>()

        for folder in folders {
            let values = try folder.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
            guard values.isDirectory == true, values.isSymbolicLink != true else {
                throw FileOperationError.notDirectory(folder)
            }
            let parent = folder.deletingLastPathComponent()
            let children = try fileManager.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: []
            )
            for child in children {
                let isDirectory = try child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
                let preferredName = isDirectory ? child.lastPathComponent : child.deletingPathExtension().lastPathComponent
                let pathExtension = isDirectory ? "" : child.pathExtension
                var target = uniqueURL(in: parent, preferredName: preferredName, pathExtension: pathExtension)
                var index = 2
                while reservedPaths.contains(target.standardizedFileURL.path) {
                    target = uniqueURL(
                        in: parent,
                        preferredName: "\(preferredName) \(index)",
                        pathExtension: pathExtension
                    )
                    index += 1
                }
                reservedPaths.insert(target.standardizedFileURL.path)
                moves.append((child, target))
            }
        }

        var completed: [(source: URL, target: URL)] = []
        do {
            for move in moves {
                try fileManager.moveItem(at: move.source, to: move.target)
                completed.append(move)
            }
            for folder in folders {
                try fileManager.removeItem(at: folder)
            }
        } catch {
            for folder in folders where !fileManager.fileExists(atPath: folder.path) {
                try? fileManager.createDirectory(at: folder, withIntermediateDirectories: false)
            }
            for move in completed.reversed() where fileManager.fileExists(atPath: move.target.path) {
                try? fileManager.moveItem(at: move.target, to: move.source)
            }
            throw error
        }
    }

    static func toggleHidden(_ urls: [URL]) throws {
        for url in urls {
            var values = try url.resourceValues(forKeys: [.isHiddenKey])
            values.isHidden = !(values.isHidden ?? false)
            var mutableURL = url
            try mutableURL.setResourceValues(values)
        }
    }

    static func setHidden(_ hidden: Bool, for urls: [URL]) throws {
        for url in urls {
            var values = URLResourceValues()
            values.isHidden = hidden
            var mutableURL = url
            try mutableURL.setResourceValues(values)
        }
    }

    static func setHiddenForContents(_ hidden: Bool, in directory: URL) throws {
        let values = try directory.resourceValues(forKeys: [.isDirectoryKey])
        guard values.isDirectory == true else { throw FileOperationError.notDirectory(directory) }
        let children = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: []
        )
        try setHidden(hidden, for: children)
    }

    static func toggleHiddenExtension(for urls: [URL]) throws {
        for url in urls {
            let current = try url.resourceValues(forKeys: [.hasHiddenExtensionKey]).hasHiddenExtension ?? false
            var values = URLResourceValues()
            values.hasHiddenExtension = !current
            var mutableURL = url
            try mutableURL.setResourceValues(values)
        }
    }

    static func grantOwnerWritePermission(to urls: [URL]) throws {
        for url in urls {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let current = (attributes[.posixPermissions] as? NSNumber)?.uint16Value ?? 0
            try FileManager.default.setAttributes(
                [.posixPermissions: NSNumber(value: current | 0o200)],
                ofItemAtPath: url.path
            )
        }
    }

    static func proposedFilenameRepairs(for urls: [URL]) throws -> [FilenameRepair] {
        var repairs: [FilenameRepair] = []
        var reservedPaths = Set<String>()
        for source in urls {
            guard let repairedName = repairedFilename(source.lastPathComponent) else { continue }
            let isDirectory = try source.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
            let pathExtension = isDirectory ? "" : (repairedName as NSString).pathExtension
            let preferredName = isDirectory
                ? repairedName
                : (repairedName as NSString).deletingPathExtension
            var target = uniqueURL(
                in: source.deletingLastPathComponent(),
                preferredName: preferredName,
                pathExtension: pathExtension
            )
            var index = 2
            while reservedPaths.contains(target.standardizedFileURL.path) {
                target = uniqueURL(
                    in: source.deletingLastPathComponent(),
                    preferredName: "\(preferredName) \(index)",
                    pathExtension: pathExtension
                )
                index += 1
            }
            reservedPaths.insert(target.standardizedFileURL.path)
            repairs.append(FilenameRepair(source: source, target: target))
        }
        return repairs
    }

    static func applyFilenameRepairs(_ repairs: [FilenameRepair]) throws {
        var completed: [FilenameRepair] = []
        do {
            for repair in repairs {
                try FileManager.default.moveItem(at: repair.source, to: repair.target)
                completed.append(repair)
            }
        } catch {
            for repair in completed.reversed() where FileManager.default.fileExists(atPath: repair.target.path) {
                try? FileManager.default.moveItem(at: repair.target, to: repair.source)
            }
            throw error
        }
    }

    static func repairedFilename(_ filename: String) -> String? {
        let originalScore = mojibakeScore(filename)
        guard originalScore >= 2 else { return nil }
        let encodings: [String.Encoding] = [.windowsCP1252, .isoLatin1, .macOSRoman]
        let candidates = encodings.compactMap { encoding -> String? in
            guard let bytes = filename.data(using: encoding),
                  let candidate = String(data: bytes, encoding: .utf8),
                  candidate != filename,
                  !candidate.contains("/"),
                  !candidate.contains("\0") else { return nil }
            return candidate.precomposedStringWithCanonicalMapping
        }
        return candidates
            .map { candidate in
                let improvement = originalScore - mojibakeScore(candidate)
                let cjkCount = candidate.unicodeScalars.filter {
                    (0x3400...0x9FFF).contains(Int($0.value))
                }.count
                return (candidate: candidate, score: improvement + cjkCount * 2)
            }
            .filter { $0.score >= 3 }
            .max(by: { $0.score < $1.score })?
            .candidate
    }

    private static func mojibakeScore(_ value: String) -> Int {
        let suspicious = Set("ÃÂäåæçéð¤¦§¨¬¯°±²³´µ¶·¸¹º»¼½¾�")
        var score = value.reduce(into: 0) { partial, character in
            if suspicious.contains(character) { partial += 1 }
        }
        let punctuation: Set<Character> = ["–", "—", "‘", "’", "“", "”", "†", "‡", "…"]
        score += value.reduce(into: 0) { partial, character in
            if punctuation.contains(character) { partial += 1 }
        }
        return score
    }

    @discardableResult
    static func createDesktopShortcuts(
        for sources: [URL],
        in desktop: URL = ConfigStore.userHomeDirectory.appendingPathComponent("Desktop", isDirectory: true)
    ) throws -> [URL] {
        guard !sources.isEmpty else { throw FileOperationError.emptySelection }
        try FileManager.default.createDirectory(at: desktop, withIntermediateDirectories: true)
        var results: [URL] = []
        for source in sources {
            let isDirectory = try source.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true
            let target = uniqueURL(
                in: desktop,
                preferredName: isDirectory ? source.lastPathComponent : source.deletingPathExtension().lastPathComponent,
                pathExtension: isDirectory ? "" : source.pathExtension
            )
            try FileManager.default.createSymbolicLink(at: target, withDestinationURL: source)
            results.append(target)
        }
        return results
    }

    static func deletePermanently(_ urls: [URL]) throws {
        guard !urls.isEmpty else { throw FileOperationError.emptySelection }
        for url in urls {
            try FileManager.default.removeItem(at: url)
        }
    }

    static func applyIconPreset(_ preset: FileIconPreset, to urls: [URL]) throws {
        let icon = makePresetIcon(preset)
        try setFileIcon(icon, for: urls)
    }

    static func applyCustomIcon(at imageURL: URL, to urls: [URL]) throws {
        guard let icon = NSImage(contentsOf: imageURL) else {
            throw FileOperationError.unsupportedImage(imageURL)
        }
        try setFileIcon(icon, for: urls)
    }

    static func removeCustomIcons(from urls: [URL]) throws {
        try setFileIcon(nil, for: urls)
    }

    private static func toolCandidates(named name: String, environmentVariable: String) -> [URL] {
        var candidates: [URL] = []
        if let override = ProcessInfo.processInfo.environment[environmentVariable], !override.isEmpty {
            candidates.append(URL(fileURLWithPath: override))
        }
        if let bundled = Bundle.main.url(forResource: name, withExtension: nil, subdirectory: "Tools") {
            candidates.append(bundled)
        }
        if let resourceURL = Bundle.main.resourceURL {
            candidates.append(resourceURL.appendingPathComponent("Tools/\(name)"))
        }
        if Bundle.main.bundleURL.pathExtension == "appex" {
            let hostContents = Bundle.main.bundleURL
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            candidates.append(hostContents.appendingPathComponent("Resources/Tools/\(name)"))
        }

        var seen = Set<String>()
        return candidates.filter { seen.insert($0.standardizedFileURL.path).inserted }
    }

    static func checksum(of url: URL, algorithm: String) throws -> String {
        let executable: URL
        let arguments: [String]
        switch algorithm.lowercased() {
        case "md5":
            executable = URL(fileURLWithPath: "/sbin/md5")
            arguments = ["-q", url.path]
        case "sha256":
            executable = URL(fileURLWithPath: "/usr/bin/shasum")
            arguments = ["-a", "256", url.path]
        case "sha1":
            executable = URL(fileURLWithPath: "/usr/bin/shasum")
            arguments = ["-a", "1", url.path]
        case "sha512":
            executable = URL(fileURLWithPath: "/usr/bin/shasum")
            arguments = ["-a", "512", url.path]
        default:
            throw FileOperationError.processFailed(L10n.format("不支持的摘要算法：%@", algorithm))
        }

        let process = Process()
        let pipe = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw FileOperationError.processFailed(output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return output.split(separator: " ").first.map(String.init) ?? output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @discardableResult
    static func createQRCode(from text: String, in directory: URL) throws -> URL {
        let data = try qrCodePNGData(from: text)
        let output = uniqueURL(in: directory, preferredName: L10n.text("二维码"), pathExtension: "png")
        try data.write(to: output, options: .atomic)
        return output
    }

    static func qrCodePNGData(from text: String) throws -> Data {
        guard !text.isEmpty else { throw FileOperationError.processFailed("二维码内容不能为空") }
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else {
            throw FileOperationError.processFailed("当前系统不支持生成二维码")
        }
        filter.setValue(Data(text.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let source = filter.outputImage else {
            throw FileOperationError.processFailed("二维码生成失败")
        }

        let scaled = source.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let margin: CGFloat = 48
        let bounds = CGRect(
            x: 0,
            y: 0,
            width: scaled.extent.width + margin * 2,
            height: scaled.extent.height + margin * 2
        )
        let positioned = scaled.transformed(by: CGAffineTransform(
            translationX: margin - scaled.extent.minX,
            y: margin - scaled.extent.minY
        ))
        let background = CIImage(color: CIColor.white).cropped(to: bounds)
        let image = positioned.composited(over: background)
        let context = CIContext()
        guard let cgImage = context.createCGImage(image, from: bounds.integral) else {
            throw FileOperationError.processFailed("二维码渲染失败")
        }
        let representation = NSBitmapImageRep(cgImage: cgImage)
        guard let data = representation.representation(using: .png, properties: [:]) else {
            throw FileOperationError.processFailed("二维码编码失败")
        }
        return data
    }

    static func convertImages(_ urls: [URL], to type: NSBitmapImageRep.FileType) throws {
        for url in urls {
            guard let image = NSImage(contentsOf: url),
                  let tiff = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff) else {
                throw FileOperationError.unsupportedImage(url)
            }
            let fileExtension = type == .png ? "png" : "jpg"
            let output = uniqueURL(
                in: url.deletingLastPathComponent(),
                preferredName: url.deletingPathExtension().lastPathComponent,
                pathExtension: fileExtension
            )
            let properties: [NSBitmapImageRep.PropertyKey: Any] = type == .jpeg ? [.compressionFactor: 0.9] : [:]
            guard let data = bitmap.representation(using: type, properties: properties) else {
                throw FileOperationError.unsupportedImage(url)
            }
            try data.write(to: output, options: .atomic)
        }
    }

    static func convertImagesToHEIC(_ urls: [URL]) throws {
        try convertImagesWithSIPS(urls, format: "heic", pathExtension: "heic")
    }

    static func convertImagesToWebP(_ urls: [URL]) throws {
        let candidates = toolCandidates(
            named: "webp-encoder",
            environmentVariable: "VIBERIGHT_WEBP_TOOL"
        ) + [
            URL(fileURLWithPath: "/opt/homebrew/bin/cwebp"),
            URL(fileURLWithPath: "/usr/local/bin/cwebp"),
            URL(fileURLWithPath: "/usr/bin/cwebp")
        ]
        guard let executable = candidates.first(where: {
            FileManager.default.isExecutableFile(atPath: $0.path)
        }) else {
            throw FileOperationError.processFailed("找不到内置 WebP 编码器")
        }
        for url in urls {
            let output = uniqueURL(
                in: url.deletingLastPathComponent(),
                preferredName: url.deletingPathExtension().lastPathComponent,
                pathExtension: "webp"
            )
            let temporaryDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("VibeRight-WebP-\(UUID().uuidString)", isDirectory: true)
            do {
                try FileManager.default.createDirectory(
                    at: temporaryDirectory,
                    withIntermediateDirectories: false
                )
                defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

                var temporaryInput = temporaryDirectory.appendingPathComponent("input")
                if !url.pathExtension.isEmpty {
                    temporaryInput.appendPathExtension(url.pathExtension)
                }
                let temporaryOutput = temporaryDirectory.appendingPathComponent("output.webp")
                try FileManager.default.copyItem(at: url, to: temporaryInput)
                _ = try runProcess(
                    executable: executable,
                    arguments: ["-quiet", "-q", "90", temporaryInput.path, "-o", temporaryOutput.path]
                )
                try validateWebP(at: temporaryOutput)
                try FileManager.default.copyItem(at: temporaryOutput, to: output)
            } catch {
                try? FileManager.default.removeItem(at: output)
                throw error
            }
        }
    }

    private static func validateWebP(at url: URL) throws {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        guard data.count >= 12,
              String(data: data.prefix(4), encoding: .ascii) == "RIFF",
              String(data: data.dropFirst(8).prefix(4), encoding: .ascii) == "WEBP",
              NSImage(contentsOf: url) != nil else {
            throw FileOperationError.unsupportedImage(url)
        }
    }

    static func convertImagesToICNS(_ urls: [URL]) throws {
        for url in urls {
            let temporary = FileManager.default.temporaryDirectory
                .appendingPathComponent("VibeRight-\(UUID().uuidString).iconset", isDirectory: true)
            defer { try? FileManager.default.removeItem(at: temporary) }
            try writeMacIconSet(from: url, to: temporary)
            let output = uniqueURL(
                in: url.deletingLastPathComponent(),
                preferredName: url.deletingPathExtension().lastPathComponent,
                pathExtension: "icns"
            )
            do {
                _ = try runProcess(
                    executable: URL(fileURLWithPath: "/usr/bin/iconutil"),
                    arguments: ["-c", "icns", "-o", output.path, temporary.path]
                )
            } catch {
                try? FileManager.default.removeItem(at: output)
                throw error
            }
        }
    }

    @discardableResult
    static func createMacIconSets(_ urls: [URL]) throws -> [URL] {
        var results: [URL] = []
        for url in urls {
            let destination = uniqueURL(
                in: url.deletingLastPathComponent(),
                preferredName: url.deletingPathExtension().lastPathComponent,
                pathExtension: "iconset"
            )
            try writeMacIconSet(from: url, to: destination)
            results.append(destination)
        }
        return results
    }

    @discardableResult
    static func createIOSIconSets(_ urls: [URL]) throws -> [URL] {
        let specifications: [(filename: String, points: String, scale: String, idiom: String, pixels: Int)] = [
            ("AppIcon-20@2x.png", "20x20", "2x", "iphone", 40),
            ("AppIcon-20@3x.png", "20x20", "3x", "iphone", 60),
            ("AppIcon-29@2x.png", "29x29", "2x", "iphone", 58),
            ("AppIcon-29@3x.png", "29x29", "3x", "iphone", 87),
            ("AppIcon-40@2x.png", "40x40", "2x", "iphone", 80),
            ("AppIcon-40@3x.png", "40x40", "3x", "iphone", 120),
            ("AppIcon-60@2x.png", "60x60", "2x", "iphone", 120),
            ("AppIcon-60@3x.png", "60x60", "3x", "iphone", 180),
            ("AppIcon-76.png", "76x76", "1x", "ipad", 76),
            ("AppIcon-76@2x.png", "76x76", "2x", "ipad", 152),
            ("AppIcon-83.5@2x.png", "83.5x83.5", "2x", "ipad", 167),
            ("AppIcon-1024.png", "1024x1024", "1x", "ios-marketing", 1024)
        ]
        var results: [URL] = []
        for url in urls {
            guard let image = NSImage(contentsOf: url) else { throw FileOperationError.unsupportedImage(url) }
            let destination = uniqueURL(
                in: url.deletingLastPathComponent(),
                preferredName: url.deletingPathExtension().lastPathComponent + " AppIcon",
                pathExtension: "appiconset"
            )
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
            do {
                var entries: [[String: String]] = []
                for specification in specifications {
                    try writeSquarePNG(
                        image,
                        pixels: specification.pixels,
                        to: destination.appendingPathComponent(specification.filename)
                    )
                    entries.append([
                        "filename": specification.filename,
                        "idiom": specification.idiom,
                        "scale": specification.scale,
                        "size": specification.points
                    ])
                }
                let contents: [String: Any] = [
                    "images": entries,
                    "info": ["author": "xcode", "version": 1]
                ]
                let data = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
                try data.write(to: destination.appendingPathComponent("Contents.json"), options: .atomic)
                results.append(destination)
            } catch {
                try? FileManager.default.removeItem(at: destination)
                throw error
            }
        }
        return results
    }

    private static func convertImagesWithSIPS(_ urls: [URL], format: String, pathExtension: String) throws {
        for url in urls {
            let output = uniqueURL(
                in: url.deletingLastPathComponent(),
                preferredName: url.deletingPathExtension().lastPathComponent,
                pathExtension: pathExtension
            )
            do {
                _ = try runProcess(
                    executable: URL(fileURLWithPath: "/usr/bin/sips"),
                    arguments: ["-s", "format", format, url.path, "--out", output.path]
                )
            } catch {
                try? FileManager.default.removeItem(at: output)
                throw error
            }
        }
    }

    private static func writeMacIconSet(from url: URL, to destination: URL) throws {
        guard let image = NSImage(contentsOf: url) else { throw FileOperationError.unsupportedImage(url) }
        let specifications: [(String, Int)] = [
            ("icon_16x16.png", 16),
            ("icon_16x16@2x.png", 32),
            ("icon_32x32.png", 32),
            ("icon_32x32@2x.png", 64),
            ("icon_128x128.png", 128),
            ("icon_128x128@2x.png", 256),
            ("icon_256x256.png", 256),
            ("icon_256x256@2x.png", 512),
            ("icon_512x512.png", 512),
            ("icon_512x512@2x.png", 1024)
        ]
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
        do {
            for (filename, pixels) in specifications {
                try writeSquarePNG(image, pixels: pixels, to: destination.appendingPathComponent(filename))
            }
        } catch {
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }

    private static func writeSquarePNG(_ image: NSImage, pixels: Int, to output: URL) throws {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw FileOperationError.unsupportedImage(output)
        }

        let canvas = NSRect(x: 0, y: 0, width: pixels, height: pixels)
        let scale = min(CGFloat(pixels) / image.size.width, CGFloat(pixels) / image.size.height)
        let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        let destination = NSRect(
            x: (CGFloat(pixels) - size.width) / 2,
            y: (CGFloat(pixels) - size.height) / 2,
            width: size.width,
            height: size.height
        )
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        NSColor.clear.setFill()
        canvas.fill()
        image.draw(in: destination, from: .zero, operation: .sourceOver, fraction: 1)
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw FileOperationError.unsupportedImage(output)
        }
        try data.write(to: output, options: .atomic)
    }

    private static func setFileIcon(_ icon: NSImage?, for urls: [URL]) throws {
        guard !urls.isEmpty else { throw FileOperationError.emptySelection }
        for url in urls {
            guard NSWorkspace.shared.setIcon(icon, forFile: url.path, options: []) else {
                throw FileOperationError.processFailed(L10n.format("无法修改图标：%@", url.lastPathComponent))
            }
        }
    }

    private static func makePresetIcon(_ preset: FileIconPreset) -> NSImage {
        let color: NSColor
        switch preset {
        case .app: color = .systemPurple
        case .apple: color = .darkGray
        case .book: color = .systemOrange
        case .calendar: color = .systemRed
        case .cloud: color = .systemBlue
        case .document: color = .systemTeal
        case .mail: color = .systemBlue
        case .music: color = .systemPink
        case .pictures: color = .systemGreen
        case .presentation: color = .systemOrange
        case .video: color = .systemIndigo
        }
        let size = NSSize(width: 256, height: 256)
        let icon = NSImage(size: size, flipped: false) { rect in
            color.setFill()
            NSBezierPath(roundedRect: rect.insetBy(dx: 8, dy: 8), xRadius: 52, yRadius: 52).fill()
            let configuration = NSImage.SymbolConfiguration(pointSize: 112, weight: .semibold)
                .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
            guard let symbol = NSImage(systemSymbolName: preset.symbolName, accessibilityDescription: nil)?
                .withSymbolConfiguration(configuration) else { return true }
            let symbolSize = symbol.size
            let destination = NSRect(
                x: (rect.width - symbolSize.width) / 2,
                y: (rect.height - symbolSize.height) / 2,
                width: symbolSize.width,
                height: symbolSize.height
            )
            symbol.draw(in: destination)
            return true
        }
        icon.isTemplate = false
        return icon
    }

    private enum OfficeDocumentKind {
        case word
        case spreadsheet
        case presentation

        init?(fileExtension: String) {
            switch fileExtension.lowercased() {
            case "docx": self = .word
            case "xlsx": self = .spreadsheet
            case "pptx": self = .presentation
            default: return nil
            }
        }
    }

    private static func createOfficeDocument(_ kind: OfficeDocumentKind, at output: URL) throws {
        let files: [String: String]
        switch kind {
        case .word:
            files = [
                "[Content_Types].xml": """
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
                  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
                  <Default Extension="xml" ContentType="application/xml"/>
                  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
                </Types>
                """,
                "_rels/.rels": """
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
                  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
                </Relationships>
                """,
                "word/document.xml": """
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
                  <w:body><w:p/></w:body>
                </w:document>
                """
            ]
        case .spreadsheet:
            files = [
                "[Content_Types].xml": """
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
                  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
                  <Default Extension="xml" ContentType="application/xml"/>
                  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
                  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
                </Types>
                """,
                "_rels/.rels": """
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
                  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
                </Relationships>
                """,
                "xl/workbook.xml": """
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
                  <sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets>
                </workbook>
                """,
                "xl/_rels/workbook.xml.rels": """
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
                  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
                </Relationships>
                """,
                "xl/worksheets/sheet1.xml": """
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData/></worksheet>
                """
            ]
        case .presentation:
            files = [
                "[Content_Types].xml": """
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
                  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
                  <Default Extension="xml" ContentType="application/xml"/>
                  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
                  <Override PartName="/ppt/slides/slide1.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>
                </Types>
                """,
                "_rels/.rels": """
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
                  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
                </Relationships>
                """,
                "ppt/presentation.xml": """
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
                  <p:sldIdLst><p:sldId id="256" r:id="rId1"/></p:sldIdLst>
                  <p:sldSz cx="12192000" cy="6858000" type="screen16x9"/>
                  <p:notesSz cx="6858000" cy="9144000"/>
                </p:presentation>
                """,
                "ppt/_rels/presentation.xml.rels": """
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
                  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide1.xml"/>
                </Relationships>
                """,
                "ppt/slides/slide1.xml": """
                <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
                <p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
                  <p:cSld><p:spTree>
                    <p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
                    <p:grpSpPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="0" cy="0"/><a:chOff x="0" y="0"/><a:chExt cx="0" cy="0"/></a:xfrm></p:grpSpPr>
                  </p:spTree></p:cSld>
                  <p:clrMapOvr><a:masterClrMapping/></p:clrMapOvr>
                </p:sld>
                """
            ]
        }

        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("VibeRight-Office-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: temporary) }
        for (relativePath, contents) in files {
            let file = temporary.appendingPathComponent(relativePath)
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(contents.utf8).write(to: file, options: .atomic)
        }
        do {
            _ = try runProcess(
                executable: URL(fileURLWithPath: "/usr/bin/zip"),
                arguments: ["-q", "-r", output.path, "."],
                currentDirectory: temporary
            )
        } catch {
            try? FileManager.default.removeItem(at: output)
            throw error
        }
    }

    @discardableResult
    private static func runProcess(
        executable: URL,
        arguments: [String],
        currentDirectory: URL? = nil,
        standardInput: Data? = nil,
        standardInputIsTerminal: Bool = false
    ) throws -> String {
        let process = Process()
        let outputPipe = Pipe()
        var inputPipe: Pipe?
        var terminalMaster: FileHandle?
        var terminalSlave: FileHandle?
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectory
        process.standardOutput = outputPipe
        process.standardError = outputPipe
        if standardInput != nil, standardInputIsTerminal {
            var masterDescriptor: Int32 = -1
            var slaveDescriptor: Int32 = -1
            guard openpty(&masterDescriptor, &slaveDescriptor, nil, nil, nil) == 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
            terminalMaster = FileHandle(fileDescriptor: masterDescriptor, closeOnDealloc: true)
            terminalSlave = FileHandle(fileDescriptor: slaveDescriptor, closeOnDealloc: true)
            process.standardInput = terminalSlave
        } else if standardInput != nil {
            let pipe = Pipe()
            inputPipe = pipe
            process.standardInput = pipe
        } else {
            process.standardInput = FileHandle.nullDevice
        }
        try process.run()
        if let standardInput {
            if let terminalMaster {
                terminalMaster.write(standardInput)
            } else if let inputPipe {
                inputPipe.fileHandleForWriting.write(standardInput)
                try? inputPipe.fileHandleForWriting.close()
            }
        }
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        try? terminalMaster?.close()
        try? terminalSlave?.close()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw FileOperationError.processFailed(output.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return output
    }
}
