import Foundation

struct FileTemplate: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var fileExtension: String
    var enabled: Bool
    var isDirectory: Bool
    var templatePath: String? = nil
    var showInMainMenu: Bool

    init(
        id: String,
        name: String,
        fileExtension: String,
        enabled: Bool,
        isDirectory: Bool,
        templatePath: String? = nil,
        showInMainMenu: Bool = false
    ) {
        self.id = id
        self.name = name
        self.fileExtension = fileExtension
        self.enabled = enabled
        self.isDirectory = isDirectory
        self.templatePath = templatePath
        self.showInMainMenu = showInMainMenu
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, fileExtension, enabled, isDirectory, templatePath, showInMainMenu
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        fileExtension = try values.decode(String.self, forKey: .fileExtension)
        enabled = try values.decode(Bool.self, forKey: .enabled)
        isDirectory = try values.decode(Bool.self, forKey: .isDirectory)
        templatePath = try values.decodeIfPresent(String.self, forKey: .templatePath)
        showInMainMenu = try values.decodeIfPresent(Bool.self, forKey: .showInMainMenu) ?? false
    }
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

    static func builtIn(
        _ id: String,
        _ name: String,
        _ bundleIdentifiers: [String],
        symbol: String = "app",
        enabled: Bool = false
    ) -> ExternalApplication {
        ExternalApplication(
            id: id,
            name: name,
            bundleIdentifiers: bundleIdentifiers,
            symbolName: symbol,
            enabled: enabled,
            isBuiltIn: true
        )
    }
}

enum TerminalOpenMode: String, Codable, CaseIterable {
    case window
    case tab

    var title: String {
        switch self {
        case .window: return L10n.text("新窗口")
        case .tab: return L10n.text("新标签页")
        }
    }
}

enum AlternateMenuModifier: String, Codable, CaseIterable {
    case shift
    case control
    case option
    case command

    var title: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }
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
        let key: String
        switch self {
        case .app: key = "App"
        case .apple: key = "Apple"
        case .book: key = "书本"
        case .calendar: key = "日历"
        case .cloud: key = "云端"
        case .document: key = "文件"
        case .mail: key = "邮件"
        case .music: key = "音乐"
        case .pictures: key = "图片"
        case .presentation: key = "演示"
        case .video: key = "视频"
        }
        return L10n.text(key)
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
    case generateQRCode
    case permanentDelete
    case compress7Z
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
        let key: String
        switch self {
        case .createDesktopShortcut: key = "发送快捷方式到桌面"
        case .shareAirDrop: key = "隔空投送"
        case .copyName: key = "拷贝文件（夹）名称"
        case .copyPath: key = "拷贝路径"
        case .fileInfo: key = "文件信息"
        case .createFolderFromName: key = "使用文件名新建文件夹"
        case .cut: key = "剪切"
        case .dissolveFolder: key = "解散文件夹"
        case .setWallpaper: key = "设置为墙纸"
        case .addToFavorites: key = "添加到常用目录"
        case .grantWritePermission: key = "授予选择的文件写入权限"
        case .hideAll: key = "隐藏所有文件"
        case .unhideAll: key = "取消隐藏所有文件"
        case .hideSelected: key = "隐藏已选文件"
        case .unhideSelected: key = "取消隐藏已选文件"
        case .toggleFileExtension: key = "隐藏/显示文件扩展名"
        case .repairFilename: key = "修复乱码文件名"
        case .generateQRCode: key = "根据路径生成二维码"
        case .permanentDelete: key = "彻底删除"
        case .compress7Z: key = "压缩为 7z"
        case .compressZIP: key = "压缩为 ZIP"
        case .extractArchive: key = "解压到当前文件夹"
        case .toggleHidden: key = "隐藏/取消隐藏"
        case .openTerminal: key = "进入终端"
        case .openWarp: key = "进入 Warp"
        case .openITerm2: key = "进入 iTerm2"
        case .openVSCode: key = "进入 Visual Studio Code"
        case .openCursor: key = "使用 Cursor 打开"
        case .openGoLand: key = "进入 GoLand"
        case .convertPNG: key = "图片转换为 PNG"
        case .convertJPEG: key = "图片转换为 JPEG"
        case .convertWebP: key = "图片转换为 WebP"
        case .convertHEIC: key = "图片转换为 HEIC"
        case .convertICNS: key = "图片转换为 ICNS"
        case .makeMacIconSet: key = "生成 macOS 图标集"
        case .makeIOSIconSet: key = "生成 iOS 图标集"
        }
        return L10n.text(key)
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
        case .generateQRCode: return "qrcode"
        case .permanentDelete: return "trash.slash"
        case .compress7Z, .compressZIP: return "archivebox"
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
        .generateQRCode,
        .permanentDelete,
        .compress7Z,
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
    var language: AppLanguage
    var templates: [FileTemplate]
    var destinations: [Destination]
    var favorites: [Destination]
    var applications: [ExternalApplication]
    var enabledIconPresets: Set<FileIconPreset>
    var customIcons: [CustomFileIcon]
    var enabledTools: Set<ToolActionID>
    var toolOrder: [ToolActionID]
    var toolCustomTitles: [String: String]
    var showIcons: Bool
    var showMenuBarIcon: Bool
    var includeExternalVolumes: Bool
    var modifierRightClickEnabled: Bool
    var modifierRightClickModifier: AlternateMenuModifier
    var middleClickEnabled: Bool
    var threeFingerTapEnabled: Bool
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
    var terminalOpenMode: TerminalOpenMode
    var iTermOpenMode: TerminalOpenMode

    static let defaultTemplates = [
        FileTemplate(id: "folder", name: "文件夹", fileExtension: "", enabled: true, isDirectory: true),
        FileTemplate(id: "txt", name: "TXT", fileExtension: "txt", enabled: true, isDirectory: false),
        FileTemplate(id: "rtf", name: "RTF", fileExtension: "rtf", enabled: true, isDirectory: false),
        FileTemplate(id: "xml", name: "XML", fileExtension: "xml", enabled: true, isDirectory: false),
        FileTemplate(id: "docx", name: "Word", fileExtension: "docx", enabled: true, isDirectory: false),
        FileTemplate(id: "xlsx", name: "Excel", fileExtension: "xlsx", enabled: true, isDirectory: false),
        FileTemplate(id: "pptx", name: "PowerPoint", fileExtension: "pptx", enabled: true, isDirectory: false),
        FileTemplate(id: "wps", name: "WPS 文字", fileExtension: "wps", enabled: true, isDirectory: false),
        FileTemplate(id: "et", name: "WPS 表格", fileExtension: "et", enabled: true, isDirectory: false),
        FileTemplate(id: "dps", name: "WPS 演示", fileExtension: "dps", enabled: true, isDirectory: false),
        FileTemplate(id: "ai", name: "Ai", fileExtension: "ai", enabled: false, isDirectory: false),
        FileTemplate(id: "psd", name: "PSD", fileExtension: "psd", enabled: false, isDirectory: false),
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
        ExternalApplication.builtIn("terminal", "终端", ["com.apple.Terminal"], symbol: "terminal", enabled: true),
        ExternalApplication.builtIn("iterm2", "iTerm2", ["com.googlecode.iterm2"], symbol: "terminal.fill", enabled: true),
        ExternalApplication.builtIn("warp", "Warp", ["dev.warp.Warp-Stable", "dev.warp.Warp"], symbol: "terminal.fill", enabled: true),
        ExternalApplication.builtIn("vscode", "Visual Studio Code", ["com.microsoft.VSCode", "com.microsoft.VSCodeInsiders"], symbol: "chevron.left.forwardslash.chevron.right", enabled: true),
        ExternalApplication.builtIn("cursor", "Cursor", ["com.todesktop.230313mzl4w4u92"], symbol: "cursorarrow.rays", enabled: true),
        ExternalApplication.builtIn("goland", "GoLand", ["com.jetbrains.goland"], symbol: "hammer", enabled: true),
        ExternalApplication.builtIn("sublime-text", "Sublime Text", ["com.sublimetext.4", "com.sublimetext.3"]),
        ExternalApplication.builtIn("sublime-merge", "Sublime Merge", ["com.sublimemerge"]),
        ExternalApplication.builtIn("marktext", "MarkText", ["com.github.marktext.marktext"]),
        ExternalApplication.builtIn("obsidian", "Obsidian", ["md.obsidian"], symbol: "diamond"),
        ExternalApplication.builtIn("tabby", "Tabby", ["org.tabby", "org.tabby-terminal"]),
        ExternalApplication.builtIn("visual-studio", "Visual Studio", ["com.microsoft.visual-studio"]),
        ExternalApplication.builtIn("hyper", "Hyper", ["co.zeit.hyper"]),
        ExternalApplication.builtIn("emacs", "Emacs", ["org.gnu.Emacs"]),
        ExternalApplication.builtIn("clion", "CLion", ["com.jetbrains.CLion"], symbol: "hammer"),
        ExternalApplication.builtIn("coteditor", "CotEditor", ["com.coteditor.CotEditor"]),
        ExternalApplication.builtIn("hbuilderx", "HBuilderX", ["io.dcloud.HBuilderX", "com.dcloud.HBuilderX"]),
        ExternalApplication.builtIn("phpstorm", "PhpStorm", ["com.jetbrains.PhpStorm"], symbol: "hammer"),
        ExternalApplication.builtIn("pycharm", "PyCharm", ["com.jetbrains.PyCharm", "com.jetbrains.pycharm"], symbol: "hammer"),
        ExternalApplication.builtIn("typora", "Typora", ["abnerworks.Typora"]),
        ExternalApplication.builtIn("webstorm", "WebStorm", ["com.jetbrains.WebStorm"], symbol: "hammer"),
        ExternalApplication.builtIn("idea", "IntelliJ IDEA", ["com.jetbrains.intellij", "com.jetbrains.intellij.ce"], symbol: "hammer"),
        ExternalApplication.builtIn("android-studio", "Android Studio", ["com.google.android.studio"], symbol: "hammer"),
        ExternalApplication.builtIn("appcode", "AppCode", ["com.jetbrains.AppCode"], symbol: "hammer"),
        ExternalApplication.builtIn("datagrip", "DataGrip", ["com.jetbrains.datagrip"], symbol: "hammer"),
        ExternalApplication.builtIn("rider", "Rider", ["com.jetbrains.rider"], symbol: "hammer"),
        ExternalApplication.builtIn("rubymine", "RubyMine", ["com.jetbrains.rubymine"], symbol: "hammer")
    ]

    static let defaults = AppConfig(
        schemaVersion: 22,
        language: .system,
        templates: defaultTemplates,
        destinations: defaultDestinations,
        favorites: defaultFavorites,
        applications: defaultApplications,
        enabledIconPresets: Set(FileIconPreset.allCases),
        customIcons: [],
        enabledTools: Set(ToolActionID.settingsCases),
        toolOrder: ToolActionID.settingsCases,
        toolCustomTitles: [:],
        showIcons: true,
        showMenuBarIcon: true,
        includeExternalVolumes: false,
        modifierRightClickEnabled: false,
        modifierRightClickModifier: .shift,
        middleClickEnabled: false,
        threeFingerTapEnabled: false,
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
        pendingCutItemsHidden: false,
        terminalOpenMode: .window,
        iTermOpenMode: .window
    )

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case language
        case templates
        case destinations
        case favorites
        case applications
        case enabledIconPresets
        case customIcons
        case enabledTools
        case toolOrder
        case toolCustomTitles
        case showIcons
        case showMenuBarIcon
        case includeExternalVolumes
        case modifierRightClickEnabled
        case modifierRightClickModifier
        case middleClickEnabled
        case threeFingerTapEnabled
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
        case terminalOpenMode
        case iTermOpenMode
    }

    init(
        schemaVersion: Int,
        language: AppLanguage,
        templates: [FileTemplate],
        destinations: [Destination],
        favorites: [Destination],
        applications: [ExternalApplication],
        enabledIconPresets: Set<FileIconPreset>,
        customIcons: [CustomFileIcon],
        enabledTools: Set<ToolActionID>,
        toolOrder: [ToolActionID],
        toolCustomTitles: [String: String],
        showIcons: Bool,
        showMenuBarIcon: Bool,
        includeExternalVolumes: Bool,
        modifierRightClickEnabled: Bool,
        modifierRightClickModifier: AlternateMenuModifier,
        middleClickEnabled: Bool,
        threeFingerTapEnabled: Bool,
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
        pendingCutItemsHidden: Bool,
        terminalOpenMode: TerminalOpenMode,
        iTermOpenMode: TerminalOpenMode
    ) {
        self.schemaVersion = schemaVersion
        self.language = language
        self.templates = templates
        self.destinations = destinations
        self.favorites = favorites
        self.applications = applications
        self.enabledIconPresets = enabledIconPresets
        self.customIcons = customIcons
        self.enabledTools = enabledTools
        self.toolOrder = toolOrder
        self.toolCustomTitles = toolCustomTitles
        self.showIcons = showIcons
        self.showMenuBarIcon = showMenuBarIcon
        self.includeExternalVolumes = includeExternalVolumes
        self.modifierRightClickEnabled = modifierRightClickEnabled
        self.modifierRightClickModifier = modifierRightClickModifier
        self.middleClickEnabled = middleClickEnabled
        self.threeFingerTapEnabled = threeFingerTapEnabled
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
        self.terminalOpenMode = terminalOpenMode
        self.iTermOpenMode = iTermOpenMode
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        language = try values.decodeIfPresent(AppLanguage.self, forKey: .language) ?? .system
        templates = try values.decodeIfPresent([FileTemplate].self, forKey: .templates) ?? Self.defaultTemplates
        destinations = try values.decodeIfPresent([Destination].self, forKey: .destinations) ?? Self.defaultDestinations
        favorites = try values.decodeIfPresent([Destination].self, forKey: .favorites) ?? destinations
        applications = try values.decodeIfPresent([ExternalApplication].self, forKey: .applications) ?? []
        enabledIconPresets = try values.decodeIfPresent(Set<FileIconPreset>.self, forKey: .enabledIconPresets) ?? Set(FileIconPreset.allCases)
        customIcons = try values.decodeIfPresent([CustomFileIcon].self, forKey: .customIcons) ?? []
        enabledTools = try values.decodeIfPresent(Set<ToolActionID>.self, forKey: .enabledTools) ?? Set(ToolActionID.settingsCases)
        toolOrder = (try? values.decode([ToolActionID].self, forKey: .toolOrder)) ?? ToolActionID.settingsCases
        toolCustomTitles = try values.decodeIfPresent([String: String].self, forKey: .toolCustomTitles) ?? [:]
        showIcons = try values.decodeIfPresent(Bool.self, forKey: .showIcons) ?? true
        showMenuBarIcon = try values.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? true
        includeExternalVolumes = try values.decodeIfPresent(Bool.self, forKey: .includeExternalVolumes) ?? false
        modifierRightClickEnabled = try values.decodeIfPresent(Bool.self, forKey: .modifierRightClickEnabled) ?? false
        modifierRightClickModifier = try values.decodeIfPresent(AlternateMenuModifier.self, forKey: .modifierRightClickModifier) ?? .shift
        middleClickEnabled = try values.decodeIfPresent(Bool.self, forKey: .middleClickEnabled) ?? false
        threeFingerTapEnabled = try values.decodeIfPresent(Bool.self, forKey: .threeFingerTapEnabled) ?? false
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
        terminalOpenMode = try values.decodeIfPresent(TerminalOpenMode.self, forKey: .terminalOpenMode) ?? .window
        iTermOpenMode = try values.decodeIfPresent(TerminalOpenMode.self, forKey: .iTermOpenMode) ?? .window
    }

    func title(for tool: ToolActionID) -> String {
        let custom = toolCustomTitles[tool.rawValue]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return custom.isEmpty ? tool.title : custom
    }

    func orderedTools(from tools: [ToolActionID]) -> [ToolActionID] {
        let available = Set(tools)
        var seen = Set<ToolActionID>()
        return (toolOrder + tools).filter {
            available.contains($0) && seen.insert($0).inserted
        }
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
        L10n.configure(language: config.language)
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
        L10n.configure(language: config.language)
    }

    func update(_ transform: (inout AppConfig) -> Void) throws {
        transform(&config)
        L10n.configure(language: config.language)
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
        if schemaVersion < 14 {
            for application in AppConfig.defaultApplications
                where !decoded.applications.contains(where: { $0.id == application.id }) {
                decoded.applications.append(application)
            }
            decoded.schemaVersion = 14
        }
        if schemaVersion < 15 {
            decoded.terminalOpenMode = .window
            decoded.iTermOpenMode = .window
            decoded.schemaVersion = 15
        }
        if schemaVersion < 16 {
            decoded.enabledTools.insert(.generateQRCode)
            decoded.schemaVersion = 16
        }
        if schemaVersion < 17 {
            decoded.toolOrder = ToolActionID.settingsCases
            decoded.toolCustomTitles = [:]
            decoded.schemaVersion = 17
        }
        if schemaVersion < 18 {
            decoded.enabledTools.insert(.compress7Z)
            decoded.schemaVersion = 18
        }
        if schemaVersion < 19 {
            for template in AppConfig.defaultTemplates where ["wps", "et", "dps"].contains(template.id) {
                if !decoded.templates.contains(where: { $0.id == template.id }) {
                    decoded.templates.append(template)
                }
            }
            decoded.schemaVersion = 19
        }
        if schemaVersion < 20 {
            for template in AppConfig.defaultTemplates where ["ai", "psd"].contains(template.id) {
                if !decoded.templates.contains(where: { $0.id == template.id }) {
                    decoded.templates.append(template)
                }
            }
            decoded.schemaVersion = 20
        }
        if schemaVersion < 21 {
            decoded.language = .system
            decoded.schemaVersion = 21
        }
        if schemaVersion < 22 {
            decoded.modifierRightClickEnabled = false
            decoded.modifierRightClickModifier = .shift
            decoded.middleClickEnabled = false
            decoded.threeFingerTapEnabled = false
            decoded.schemaVersion = 22
        }
        let supportedTools = Set(ToolActionID.settingsCases)
        var seenTools = Set<ToolActionID>()
        decoded.toolOrder = decoded.toolOrder.filter {
            supportedTools.contains($0) && seenTools.insert($0).inserted
        }
        decoded.toolOrder.append(contentsOf: ToolActionID.settingsCases.filter { seenTools.insert($0).inserted })
        decoded.toolCustomTitles = decoded.toolCustomTitles.filter { key, value in
            ToolActionID(rawValue: key).map(supportedTools.contains) == true
                && !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return decoded
    }
}
