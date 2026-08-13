import Foundation

struct FileTemplate: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var fileExtension: String
    var enabled: Bool
    var isDirectory: Bool
}

struct Destination: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var path: String
    var enabled: Bool

    var expandedURL: URL {
        let expanded: String
        if path == "~" {
            expanded = ConfigStore.userHomeDirectory.path
        } else if path.hasPrefix("~/") {
            expanded = ConfigStore.userHomeDirectory.appendingPathComponent(String(path.dropFirst(2))).path
        } else {
            expanded = NSString(string: path).expandingTildeInPath
        }
        return URL(fileURLWithPath: expanded, isDirectory: true)
    }
}

enum ToolActionID: String, Codable, CaseIterable {
    case copyName
    case copyPath
    case fileInfo
    case createFolderFromName
    case toggleHidden
    case openTerminal
    case openVSCode
    case openGoLand
    case convertPNG
    case convertJPEG

    var title: String {
        switch self {
        case .copyName: return "拷贝文件（夹）名称"
        case .copyPath: return "拷贝路径"
        case .fileInfo: return "文件信息"
        case .createFolderFromName: return "使用文件名新建文件夹"
        case .toggleHidden: return "隐藏/取消隐藏"
        case .openTerminal: return "进入终端"
        case .openVSCode: return "进入 Visual Studio Code"
        case .openGoLand: return "进入 GoLand"
        case .convertPNG: return "图片转换为 PNG"
        case .convertJPEG: return "图片转换为 JPEG"
        }
    }

    var symbolName: String {
        switch self {
        case .copyName: return "doc.on.doc"
        case .copyPath: return "link"
        case .fileInfo: return "info.circle"
        case .createFolderFromName: return "folder.badge.plus"
        case .toggleHidden: return "eye.slash"
        case .openTerminal: return "terminal"
        case .openVSCode: return "chevron.left.forwardslash.chevron.right"
        case .openGoLand: return "hammer"
        case .convertPNG, .convertJPEG: return "photo.badge.arrow.down"
        }
    }
}

struct AppConfig: Codable, Equatable {
    var templates: [FileTemplate]
    var destinations: [Destination]
    var enabledTools: Set<ToolActionID>
    var showIcons: Bool
    var autoOpenNewFile: Bool
    var playSound: Bool

    static let defaults = AppConfig(
        templates: [
            FileTemplate(id: "folder", name: "文件夹", fileExtension: "", enabled: true, isDirectory: true),
            FileTemplate(id: "txt", name: "TXT", fileExtension: "txt", enabled: true, isDirectory: false),
            FileTemplate(id: "md", name: "Markdown", fileExtension: "md", enabled: true, isDirectory: false),
            FileTemplate(id: "json", name: "JSON", fileExtension: "json", enabled: true, isDirectory: false),
            FileTemplate(id: "swift", name: "Swift", fileExtension: "swift", enabled: true, isDirectory: false)
        ],
        destinations: [
            Destination(id: "downloads", name: "下载", path: "~/Downloads", enabled: true),
            Destination(id: "documents", name: "文稿", path: "~/Documents", enabled: true),
            Destination(id: "pictures", name: "图片", path: "~/Pictures", enabled: true),
            Destination(id: "movies", name: "影片", path: "~/Movies", enabled: true)
        ],
        enabledTools: Set(ToolActionID.allCases),
        showIcons: true,
        autoOpenNewFile: false,
        playSound: true
    )
}

final class ConfigStore {
    static let shared = ConfigStore()

    private(set) var config: AppConfig
    let configURL: URL

    init(configURL: URL = ConfigStore.defaultConfigURL) {
        self.configURL = configURL
        self.config = Self.load(from: configURL)
    }

    static var defaultConfigURL: URL {
        let sandboxSuffix = "/Library/Containers/com.vibecoding.VibeRight.FinderExtension/Data"
        let processHome = FileManager.default.homeDirectoryForCurrentUser
        let dataHome = processHome.path.hasSuffix(sandboxSuffix)
            ? processHome
            : processHome.appendingPathComponent(String(sandboxSuffix.dropFirst()), isDirectory: true)
        return dataHome
            .appendingPathComponent("Library/Application Support/VibeRight", isDirectory: true)
            .appendingPathComponent("config.json")
    }

    static var userHomeDirectory: URL {
        let sandboxSuffix = "/Library/Containers/com.vibecoding.VibeRight.FinderExtension/Data"
        let processHome = FileManager.default.homeDirectoryForCurrentUser
        guard processHome.path.hasSuffix(sandboxSuffix) else { return processHome }
        return URL(fileURLWithPath: String(processHome.path.dropLast(sandboxSuffix.count)), isDirectory: true)
    }

    func reload() {
        config = Self.load(from: configURL)
    }

    func update(_ transform: (inout AppConfig) -> Void) throws {
        transform(&config)
        try save()
    }

    func save() throws {
        let directory = configURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(config).write(to: configURL, options: .atomic)
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name("com.vibecoding.VibeRight.configChanged"),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    private static func load(from url: URL) -> AppConfig {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            return .defaults
        }
        return decoded
    }
}
