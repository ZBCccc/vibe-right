import Foundation

struct FileTemplate: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var fileExtension: String
    var enabled: Bool
    var isDirectory: Bool
    var templatePath: String? = nil
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

struct ExternalApplication: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var bundleIdentifiers: [String]
    var symbolName: String
    var enabled: Bool
    var isBuiltIn: Bool
}

enum FileIconPreset: String, Codable, CaseIterable, Identifiable {
    case app
    case apple
    case book
    case calendar
    case cloud
    case document
    case mail
    case music
    case pictures
    case presentation
    case video

    var id: String { rawValue }

    var title: String {
        switch self {
        case .app: return "App"
        case .apple: return "Apple"
        case .book: return "书本"
        case .calendar: return "日历"
        case .cloud: return "云端"
        case .document: return "文件"
        case .mail: return "邮件"
        case .music: return "音乐"
        case .pictures: return "图片"
        case .presentation: return "演示"
        case .video: return "视频"
        }
    }

    var symbolName: String {
        switch self {
        case .app: return "app.fill"
        case .apple: return "apple.logo"
        case .book: return "book.closed.fill"
        case .calendar: return "calendar"
        case .cloud: return "icloud.fill"
        case .document: return "doc.fill"
        case .mail: return "envelope.fill"
        case .music: return "music.note"
        case .pictures: return "photo.fill"
        case .presentation: return "rectangle.on.rectangle.angled"
        case .video: return "play.rectangle.fill"
        }
    }
}

struct CustomFileIcon: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var path: String
    var enabled: Bool
}

enum ToolActionID: String, Codable, CaseIterable {
    case createDesktopShortcut
    case shareAirDrop
    case copyName
    case copyPath
    case fileInfo
    case createFolderFromName
    case cut
    case dissolveFolder
    case setWallpaper
    case addToFavorites
    case grantWritePermission
    case hideAll
    case unhideAll
    case hideSelected
    case unhideSelected
    case toggleFileExtension
    case repairFilename
    case permanentDelete
    case compressZIP
    case extractArchive
    // Retained only so version 1-3 configuration files remain decodable.
    case toggleHidden
    case openTerminal
    case openWarp
    case openITerm2
    case openVSCode
    case openCursor
    case openGoLand
    case convertPNG
    case convertJPEG
    case convertWebP
    case convertHEIC
    case convertICNS
    case makeMacIconSet
    case makeIOSIconSet

    var title: String {
        switch self {
        case .createDesktopShortcut: return "发送快捷方式到桌面"
        case .shareAirDrop: return "隔空投送"
        case .copyName: return "拷贝文件（夹）名称"
        case .copyPath: return "拷贝路径"
        case .fileInfo: return "文件信息"
        case .createFolderFromName: return "使用文件名新建文件夹"
        case .cut: return "剪切"
        case .dissolveFolder: return "解散文件夹"
        case .setWallpaper: return "设置为墙纸"
        case .addToFavorites: return "添加到常用目录"
        case .grantWritePermission: return "授予选择的文件写入权限"
        case .hideAll: return "隐藏所有文件"
        case .unhideAll: return "取消隐藏所有文件"
        case .hideSelected: return "隐藏已选文件"
        case .unhideSelected: return "取消隐藏已选文件"
        case .toggleFileExtension: return "隐藏/显示文件扩展名"
        case .repairFilename: return "修复乱码文件名"
        case .permanentDelete: return "彻底删除"
        case .compressZIP: return "压缩为 ZIP"
        case .extractArchive: return "解压到当前文件夹"
        case .toggleHidden: return "隐藏/取消隐藏"
        case .openTerminal: return "进入终端"
        case .openWarp: return "进入 Warp"
        case .openITerm2: return "进入 iTerm2"
        case .openVSCode: return "进入 Visual Studio Code"
        case .openCursor: return "使用 Cursor 打开"
        case .openGoLand: return "进入 GoLand"
        case .convertPNG: return "图片转换为 PNG"
        case .convertJPEG: return "图片转换为 JPEG"
        case .convertWebP: return "图片转换为 WebP"
        case .convertHEIC: return "图片转换为 HEIC"
        case .convertICNS: return "图片转换为 ICNS"
        case .makeMacIconSet: return "生成 macOS 图标集"
        case .makeIOSIconSet: return "生成 iOS 图标集"
        }
    }

    var symbolName: String {
        switch self {
        case .createDesktopShortcut: return "arrow.up.forward.app"
        case .shareAirDrop: return "airplayaudio"
        case .copyName: return "doc.on.doc"
        case .copyPath: return "link"
        case .fileInfo: return "info.circle"
        case .createFolderFromName: return "folder.badge.plus"
        case .cut: return "scissors"
        case .dissolveFolder: return "arrow.up.and.down.and.arrow.left.and.right"
        case .setWallpaper: return "photo.on.rectangle.angled"
        case .addToFavorites: return "heart.badge.plus"
        case .grantWritePermission: return "lock.open"
        case .hideAll, .hideSelected: return "eye.slash"
        case .unhideAll, .unhideSelected: return "eye"
        case .toggleFileExtension: return "character.cursor.ibeam"
        case .repairFilename: return "textformat.abc.dottedunderline"
        case .permanentDelete: return "trash.slash"
        case .compressZIP: return "archivebox"
        case .extractArchive: return "archivebox.fill"
        case .toggleHidden: return "eye.slash"
        case .openTerminal: return "terminal"
        case .openWarp: return "terminal.fill"
        case .openITerm2: return "terminal.fill"
        case .openVSCode: return "chevron.left.forwardslash.chevron.right"
        case .openCursor: return "cursorarrow.rays"
        case .openGoLand: return "hammer"
        case .convertPNG, .convertJPEG, .convertWebP, .convertHEIC, .convertICNS, .makeMacIconSet, .makeIOSIconSet:
            return "photo.badge.arrow.down"
        }
    }

    static let settingsCases: [ToolActionID] = [
        .fileInfo,
        .createDesktopShortcut,
        .shareAirDrop,
        .copyName,
        .createFolderFromName,
        .cut,
        .dissolveFolder,
        .setWallpaper,
        .copyPath,
        .addToFavorites,
        .grantWritePermission,
        .unhideAll,
        .hideAll,
        .unhideSelected,
        .hideSelected,
        .toggleFileExtension,
        .repairFilename,
        .permanentDelete,
        .compressZIP,
        .extractArchive,
        .convertWebP,
        .convertHEIC,
        .convertPNG,
        .convertJPEG,
        .convertICNS,
        .makeMacIconSet,
        .makeIOSIconSet
    ]
}

struct AppConfig: Codable, Equatable {
    var schemaVersion: Int
    var templates: [FileTemplate]
    var destinations: [Destination]
    var favorites: [Destination]
    var applications: [ExternalApplication]
    var enabledIconPresets: Set<FileIconPreset>
    var customIcons: [CustomFileIcon]
    var enabledTools: Set<ToolActionID>
    var showIcons: Bool
    var showMenuBarIcon: Bool
    var includeExternalVolumes: Bool
    var autoOpenNewFile: Bool
    var playSound: Bool
    var moveEnabled: Bool
    var copyEnabled: Bool
    var favoritesEnabled: Bool
    var confirmPermanentDelete: Bool
    var mergeFileActions: Bool
    var mergeImageActions: Bool
    var mergeApplicationActions: Bool
    var hideCutItems: Bool
    var pendingCutPaths: [String]
    var pendingCutItemsHidden: Bool

    static let defaultTemplates = [
        FileTemplate(id: "folder", name: "文件夹", fileExtension: "", enabled: true, isDirectory: true),
        FileTemplate(id: "txt", name: "TXT", fileExtension: "txt", enabled: true, isDirectory: false),
        FileTemplate(id: "rtf", name: "RTF", fileExtension: "rtf", enabled: true, isDirectory: false),
        FileTemplate(id: "xml", name: "XML", fileExtension: "xml", enabled: true, isDirectory: false),
        FileTemplate(id: "docx", name: "Word", fileExtension: "docx", enabled: true, isDirectory: false),
        FileTemplate(id: "xlsx", name: "Excel", fileExtension: "xlsx", enabled: true, isDirectory: false),
        FileTemplate(id: "pptx", name: "PowerPoint", fileExtension: "pptx", enabled: true, isDirectory: false),
        FileTemplate(id: "md", name: "Markdown", fileExtension: "md", enabled: true, isDirectory: false),
        FileTemplate(id: "json", name: "JSON", fileExtension: "json", enabled: true, isDirectory: false),
        FileTemplate(id: "swift", name: "Swift", fileExtension: "swift", enabled: true, isDirectory: false)
    ]

    static let defaultDestinations = [
        Destination(id: "downloads", name: "下载", path: "~/Downloads", enabled: true),
        Destination(id: "pictures", name: "图片", path: "~/Pictures", enabled: true),
        Destination(id: "music", name: "音乐", path: "~/Music", enabled: true),
        Destination(id: "movies", name: "影片", path: "~/Movies", enabled: true),
        Destination(id: "documents", name: "文稿", path: "~/Documents", enabled: true)
    ]

    static let defaultFavorites = [
        Destination(id: "favorite-music", name: "音乐", path: "~/Music", enabled: true),
        Destination(id: "favorite-pictures", name: "图片", path: "~/Pictures", enabled: true),
        Destination(id: "favorite-movies", name: "影片", path: "~/Movies", enabled: true)
    ]

    static let defaultApplications = [
        ExternalApplication(
            id: "terminal",
            name: "终端",
            bundleIdentifiers: ["com.apple.Terminal"],
            symbolName: "terminal",
            enabled: true,
            isBuiltIn: true
        ),
        ExternalApplication(
            id: "iterm2",
            name: "iTerm2",
            bundleIdentifiers: ["com.googlecode.iterm2"],
            symbolName: "terminal.fill",
            enabled: true,
            isBuiltIn: true
        ),
        ExternalApplication(
            id: "warp",
            name: "Warp",
            bundleIdentifiers: ["dev.warp.Warp-Stable", "dev.warp.Warp"],
            symbolName: "terminal.fill",
            enabled: true,
            isBuiltIn: true
        ),
        ExternalApplication(
            id: "vscode",
            name: "Visual Studio Code",
            bundleIdentifiers: ["com.microsoft.VSCode", "com.microsoft.VSCodeInsiders"],
            symbolName: "chevron.left.forwardslash.chevron.right",
            enabled: true,
            isBuiltIn: true
        ),
        ExternalApplication(
            id: "cursor",
            name: "Cursor",
            bundleIdentifiers: ["com.todesktop.230313mzl4w4u92"],
            symbolName: "cursorarrow.rays",
            enabled: true,
            isBuiltIn: true
        ),
        ExternalApplication(
            id: "goland",
            name: "GoLand",
            bundleIdentifiers: ["com.jetbrains.goland"],
            symbolName: "hammer",
            enabled: true,
            isBuiltIn: true
        ),
        ExternalApplication(
            id: "obsidian",
            name: "Obsidian",
            bundleIdentifiers: ["md.obsidian"],
            symbolName: "diamond",
            enabled: false,
            isBuiltIn: true
        )
    ]

    static let defaults = AppConfig(
        schemaVersion: 13,
        templates: defaultTemplates,
        destinations: defaultDestinations,
        favorites: defaultFavorites,
        applications: defaultApplications,
        enabledIconPresets: Set(FileIconPreset.allCases),
        customIcons: [],
        enabledTools: Set(ToolActionID.settingsCases),
        showIcons: true,
        showMenuBarIcon: true,
        includeExternalVolumes: false,
        autoOpenNewFile: false,
        playSound: true,
        moveEnabled: true,
        copyEnabled: true,
        favoritesEnabled: true,
        confirmPermanentDelete: true,
        mergeFileActions: false,
        mergeImageActions: false,
        mergeApplicationActions: false,
        hideCutItems: false,
        pendingCutPaths: [],
        pendingCutItemsHidden: false
    )

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case templates
        case destinations
        case favorites
        case applications
        case enabledIconPresets
        case customIcons
        case enabledTools
        case showIcons
        case showMenuBarIcon
        case includeExternalVolumes
        case autoOpenNewFile
        case playSound
        case moveEnabled
        case copyEnabled
        case favoritesEnabled
        case confirmPermanentDelete
        case mergeFileActions
        case mergeImageActions
        case mergeApplicationActions
        case hideCutItems
        case pendingCutPaths
        case pendingCutItemsHidden
    }

    init(
        schemaVersion: Int,
        templates: [FileTemplate],
        destinations: [Destination],
        favorites: [Destination],
        applications: [ExternalApplication],
        enabledIconPresets: Set<FileIconPreset>,
        customIcons: [CustomFileIcon],
        enabledTools: Set<ToolActionID>,
        showIcons: Bool,
        showMenuBarIcon: Bool,
        includeExternalVolumes: Bool,
        autoOpenNewFile: Bool,
        playSound: Bool,
        moveEnabled: Bool,
        copyEnabled: Bool,
        favoritesEnabled: Bool,
        confirmPermanentDelete: Bool,
        mergeFileActions: Bool,
        mergeImageActions: Bool,
        mergeApplicationActions: Bool,
        hideCutItems: Bool,
        pendingCutPaths: [String],
        pendingCutItemsHidden: Bool
    ) {
        self.schemaVersion = schemaVersion
        self.templates = templates
        self.destinations = destinations
        self.favorites = favorites
        self.applications = applications
        self.enabledIconPresets = enabledIconPresets
        self.customIcons = customIcons
        self.enabledTools = enabledTools
        self.showIcons = showIcons
        self.showMenuBarIcon = showMenuBarIcon
        self.includeExternalVolumes = includeExternalVolumes
        self.autoOpenNewFile = autoOpenNewFile
        self.playSound = playSound
        self.moveEnabled = moveEnabled
        self.copyEnabled = copyEnabled
        self.favoritesEnabled = favoritesEnabled
        self.confirmPermanentDelete = confirmPermanentDelete
        self.mergeFileActions = mergeFileActions
        self.mergeImageActions = mergeImageActions
        self.mergeApplicationActions = mergeApplicationActions
        self.hideCutItems = hideCutItems
        self.pendingCutPaths = pendingCutPaths
        self.pendingCutItemsHidden = pendingCutItemsHidden
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        templates = try values.decodeIfPresent([FileTemplate].self, forKey: .templates) ?? Self.defaultTemplates
        destinations = try values.decodeIfPresent([Destination].self, forKey: .destinations) ?? Self.defaultDestinations
        favorites = try values.decodeIfPresent([Destination].self, forKey: .favorites) ?? destinations
        applications = try values.decodeIfPresent([ExternalApplication].self, forKey: .applications) ?? []
        enabledIconPresets = try values.decodeIfPresent(Set<FileIconPreset>.self, forKey: .enabledIconPresets) ?? Set(FileIconPreset.allCases)
        customIcons = try values.decodeIfPresent([CustomFileIcon].self, forKey: .customIcons) ?? []
        enabledTools = try values.decodeIfPresent(Set<ToolActionID>.self, forKey: .enabledTools) ?? Set(ToolActionID.settingsCases)
        showIcons = try values.decodeIfPresent(Bool.self, forKey: .showIcons) ?? true
        showMenuBarIcon = try values.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? true
        includeExternalVolumes = try values.decodeIfPresent(Bool.self, forKey: .includeExternalVolumes) ?? false
        autoOpenNewFile = try values.decodeIfPresent(Bool.self, forKey: .autoOpenNewFile) ?? false
        playSound = try values.decodeIfPresent(Bool.self, forKey: .playSound) ?? true
        moveEnabled = try values.decodeIfPresent(Bool.self, forKey: .moveEnabled) ?? true
        copyEnabled = try values.decodeIfPresent(Bool.self, forKey: .copyEnabled) ?? true
        favoritesEnabled = try values.decodeIfPresent(Bool.self, forKey: .favoritesEnabled) ?? true
        confirmPermanentDelete = try values.decodeIfPresent(Bool.self, forKey: .confirmPermanentDelete) ?? true
        mergeFileActions = try values.decodeIfPresent(Bool.self, forKey: .mergeFileActions) ?? false
        mergeImageActions = try values.decodeIfPresent(Bool.self, forKey: .mergeImageActions) ?? false
        mergeApplicationActions = try values.decodeIfPresent(Bool.self, forKey: .mergeApplicationActions) ?? false
        hideCutItems = try values.decodeIfPresent(Bool.self, forKey: .hideCutItems) ?? false
        pendingCutPaths = try values.decodeIfPresent([String].self, forKey: .pendingCutPaths) ?? []
        pendingCutItemsHidden = try values.decodeIfPresent(Bool.self, forKey: .pendingCutItemsHidden) ?? false
    }
}

final class ConfigStore {
    static let shared = ConfigStore()

    private(set) var config: AppConfig
    let configURL: URL

    var templateStorageURL: URL {
        configURL.deletingLastPathComponent().appendingPathComponent("Templates", isDirectory: true)
    }

    var iconStorageURL: URL {
        configURL.deletingLastPathComponent().appendingPathComponent("Icons", isDirectory: true)
    }

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
              var decoded = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            return .defaults
        }
        let schemaVersion = decoded.schemaVersion
        if schemaVersion < 2 {
            decoded.enabledTools.insert(.openCursor)
        }
        if schemaVersion < 3 {
            decoded.enabledTools.insert(.openWarp)
            decoded.enabledTools.insert(.openITerm2)
        }
        if schemaVersion < 4 {
            if decoded.enabledTools.remove(.toggleHidden) != nil {
                decoded.enabledTools.insert(.hideSelected)
                decoded.enabledTools.insert(.unhideSelected)
            }
            decoded.enabledTools.formUnion([
                .shareAirDrop,
                .dissolveFolder,
                .setWallpaper,
                .addToFavorites,
                .grantWritePermission,
                .hideAll,
                .unhideAll,
                .hideSelected,
                .unhideSelected,
                .toggleFileExtension
            ])
            decoded.schemaVersion = 4
        }
        if schemaVersion < 5 {
            let legacyApplications: [(String, ToolActionID)] = [
                ("terminal", .openTerminal),
                ("iterm2", .openITerm2),
                ("warp", .openWarp),
                ("vscode", .openVSCode),
                ("cursor", .openCursor),
                ("goland", .openGoLand)
            ]
            var applications = AppConfig.defaultApplications
            for (id, tool) in legacyApplications {
                if let index = applications.firstIndex(where: { $0.id == id }) {
                    applications[index].enabled = decoded.enabledTools.contains(tool)
                }
                decoded.enabledTools.remove(tool)
            }
            decoded.applications = applications
            decoded.schemaVersion = 5
        }
        if schemaVersion < 6 {
            decoded.enabledTools.formUnion([
                .createDesktopShortcut,
                .permanentDelete,
                .compressZIP,
                .extractArchive,
                .convertWebP,
                .convertHEIC,
                .convertICNS,
                .makeMacIconSet,
                .makeIOSIconSet
            ])
            decoded.schemaVersion = 6
        }
        if schemaVersion < 7 {
            for template in AppConfig.defaultTemplates where ["rtf", "xml"].contains(template.id) {
                if !decoded.templates.contains(where: { $0.id == template.id }) {
                    decoded.templates.append(template)
                }
            }
            decoded.schemaVersion = 7
        }
        if schemaVersion < 8 {
            decoded.enabledIconPresets = Set(FileIconPreset.allCases)
            decoded.schemaVersion = 8
        }
        if schemaVersion < 9 {
            for template in AppConfig.defaultTemplates where ["docx", "xlsx", "pptx"].contains(template.id) {
                if !decoded.templates.contains(where: { $0.id == template.id }) {
                    decoded.templates.append(template)
                }
            }
            decoded.schemaVersion = 9
        }
        if schemaVersion < 10 {
            decoded.showMenuBarIcon = true
            decoded.includeExternalVolumes = false
            decoded.schemaVersion = 10
        }
        if schemaVersion < 11 {
            decoded.mergeFileActions = false
            decoded.mergeImageActions = false
            decoded.mergeApplicationActions = false
            decoded.schemaVersion = 11
        }
        if schemaVersion < 12 {
            decoded.enabledTools.insert(.repairFilename)
            decoded.schemaVersion = 12
        }
        if schemaVersion < 13 {
            decoded.enabledTools.insert(.cut)
            decoded.hideCutItems = false
            decoded.pendingCutPaths = []
            decoded.pendingCutItemsHidden = false
            decoded.schemaVersion = 13
        }
        return decoded
    }
}
