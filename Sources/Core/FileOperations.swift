import AppKit
import Foundation

enum FileOperationError: LocalizedError {
    case noTargetDirectory
    case unsupportedImage(URL)
    case applicationNotFound(String)
    case processFailed(String)

    var errorDescription: String? {
        switch self {
        case .noTargetDirectory: return "无法确定目标目录"
        case .unsupportedImage(let url): return "无法读取图片：\(url.lastPathComponent)"
        case .applicationNotFound(let name): return "未安装 \(name)"
        case .processFailed(let message): return message
        }
    }
}
enum FileOperations {
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
    static func create(template: FileTemplate, in directory: URL) throws -> URL {
        let baseName = template.isDirectory ? "新建文件夹" : "未命名"
        let url = uniqueURL(in: directory, preferredName: baseName, pathExtension: template.fileExtension)
        if template.isDirectory {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
        } else {
            let initialData: Data
            switch template.fileExtension.lowercased() {
            case "json": initialData = Data("{}\n".utf8)
            case "swift": initialData = Data("import Foundation\n\n".utf8)
            default: initialData = Data()
            }
            guard FileManager.default.createFile(atPath: url.path, contents: initialData) else {
                throw CocoaError(.fileWriteUnknown)
            }
        }
        return url
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
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        for source in sources {
            let target = uniqueURL(
                in: destination,
                preferredName: source.deletingPathExtension().lastPathComponent,
                pathExtension: source.pathExtension
            )
            try FileManager.default.moveItem(at: source, to: target)
        }
    }

    static func createFoldersFromNames(for sources: [URL]) throws {
        for source in sources {
            let parent = source.deletingLastPathComponent()
            let folder = uniqueURL(in: parent, preferredName: source.deletingPathExtension().lastPathComponent)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
            try FileManager.default.moveItem(at: source, to: folder.appendingPathComponent(source.lastPathComponent))
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
        default:
            throw FileOperationError.processFailed("不支持的摘要算法：\(algorithm)")
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
}
