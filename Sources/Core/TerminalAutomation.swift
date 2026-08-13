import AppKit
import Foundation

enum TerminalApplication: String, Codable {
    case terminal
    case iTerm2 = "iterm2"

    var displayName: String {
        switch self {
        case .terminal: return "终端"
        case .iTerm2: return "iTerm2"
        }
    }

    var bundleIdentifier: String {
        switch self {
        case .terminal: return "com.apple.Terminal"
        case .iTerm2: return "com.googlecode.iterm2"
        }
    }
}

struct TerminalLaunchRequest: Equatable {
    let application: TerminalApplication
    let mode: TerminalOpenMode
    let directories: [URL]
}

enum TerminalAutomation {
    private static let scheme = "viberight"
    private static let host = "open-terminal"

    static func requestURL(for request: TerminalLaunchRequest) -> URL? {
        guard !request.directories.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.queryItems = [
            URLQueryItem(name: "application", value: request.application.rawValue),
            URLQueryItem(name: "mode", value: request.mode.rawValue)
        ] + request.directories.map {
            URLQueryItem(name: "path", value: $0.standardizedFileURL.path)
        }
        return components.url
    }

    static func parseRequestURL(_ url: URL) -> TerminalLaunchRequest? {
        guard url.scheme?.lowercased() == scheme,
              url.host?.lowercased() == host,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = components.queryItems,
              let applicationValue = items.first(where: { $0.name == "application" })?.value,
              let application = TerminalApplication(rawValue: applicationValue),
              let modeValue = items.first(where: { $0.name == "mode" })?.value,
              let mode = TerminalOpenMode(rawValue: modeValue) else {
            return nil
        }
        let directories = items
            .filter { $0.name == "path" }
            .compactMap(\.value)
            .map { URL(fileURLWithPath: $0, isDirectory: true).standardizedFileURL }
        guard !directories.isEmpty else { return nil }
        return TerminalLaunchRequest(application: application, mode: mode, directories: directories)
    }

    static func run(_ request: TerminalLaunchRequest) throws {
        for directory in request.directories {
            let values = try directory.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true else { throw FileOperationError.notDirectory(directory) }
        }
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: request.application.bundleIdentifier) != nil else {
            throw FileOperationError.applicationNotFound(request.application.displayName)
        }
        try runService(request)
    }

    static func serviceName(for application: TerminalApplication, mode: TerminalOpenMode) -> String {
        switch (application, mode) {
        case (.terminal, .window): return "New Terminal at Folder"
        case (.terminal, .tab): return "New Terminal Tab at Folder"
        case (.iTerm2, .window): return "New iTerm2 Window Here"
        case (.iTerm2, .tab): return "New iTerm2 Tab Here"
        }
    }

    private static func runService(_ request: TerminalLaunchRequest) throws {
        let serviceName = serviceName(for: request.application, mode: request.mode)
        let legacyFilenames = NSPasteboard.PasteboardType("NSFilenamesPboardType")
        for directory in request.directories {
            let pasteboard = NSPasteboard.withUniqueName()
            defer { pasteboard.releaseGlobally() }
            switch request.application {
            case .terminal:
                pasteboard.declareTypes([.string], owner: nil)
                pasteboard.setString(directory.path, forType: .string)
            case .iTerm2:
                pasteboard.declareTypes([legacyFilenames], owner: nil)
                pasteboard.setPropertyList([directory.path], forType: legacyFilenames)
            }
            guard NSPerformService(serviceName, pasteboard) else {
                throw FileOperationError.processFailed("系统服务“\(serviceName)”不可用")
            }
        }
    }
}
